import 'package:sqflite/sqflite.dart';
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

class SQLiteDatabaseService {
  static Database? _database;
  
  // Inicializar la base de datos
  static Future<void> initialize() async {
    print('🚀 Inicializando base de datos SQLite...');
    // Inicialización para escritorio (Windows, Linux, Mac)
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'smart_seller.db');
    
    _database = await openDatabase(
      path,
      version: 2,
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
  }
  
  // Crear las tablas
  static Future<void> _onCreate(Database db, int version) async {
    print('🔧 Creando tablas de la base de datos...');
    
    // Tabla de usuarios
    await db.execute('''
      CREATE TABLE users (
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
    
    // Tabla de productos
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        shortCode TEXT UNIQUE NOT NULL,
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
        isWeighted INTEGER NOT NULL DEFAULT 0,
        pricePerKg REAL,
        weight REAL,
        minWeight REAL,
        maxWeight REAL
      )
    ''');
    
    // Tabla de movimientos de inventario
    await db.execute('''
      CREATE TABLE inventory_movements (
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
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total REAL NOT NULL,
        user TEXT NOT NULL,
        paymentMethod TEXT,
        items TEXT NOT NULL
      )
    ''');
    
    // Tabla de clientes
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT,
        documentNumber TEXT,
        documentType TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        points INTEGER NOT NULL DEFAULT 0,
        membershipLevel TEXT,
        lastPurchase TEXT,
        totalPurchases REAL NOT NULL DEFAULT 0.0
      )
    ''');

    // Tabla de configuración de empresa
    await db.execute('''
      CREATE TABLE company_config (
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
      CREATE TABLE clients (
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
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Actualizando base de datos de v$oldVersion a v$newVersion');
    
    // Migración de versión 1 a 2: Agregar tabla de configuración de empresa
    if (oldVersion < 2) {
      print('🔧 Creando tabla company_config...');
      await db.execute('''
        CREATE TABLE company_config (
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
      print('✅ Tabla company_config creada');
    }
  }
  
  // Crear usuario admin por defecto
  static Future<void> _createDefaultUser() async {
    print('🔧 Verificando si existe usuario admin...');
    
    final adminExists = await _database!.query(
      'users',
      where: 'username = ?',
      whereArgs: ['admin'],
    );
    
    if (adminExists.isNotEmpty) {
      print('✅ Usuario admin ya existe, no se crea uno nuevo');
      return;
    }
    
    print('🔧 Creando usuario admin por defecto...');
    await _database!.insert('users', {
      'username': 'admin',
      'password': '123456',
      'fullName': 'Administrador',
      'role': 'admin',
      'createdAt': DateTime.now().toIso8601String(),
      'isActive': 1,
    });
    
    print('✅ Usuario admin creado: admin / 123456');
  }
  
  // ================== USUARIOS ==================
  
  // Buscar usuario por username y password
  static Future<User?> findUser(String username, String password) async {
    print('🔍 Buscando usuario: username="$username", password="$password"');
    
    try {
      final results = await _database!.query(
        'users',
        where: 'username = ? AND password = ? AND isActive = ?',
        whereArgs: [username, password, 1],
      );
      
      if (results.isNotEmpty) {
        final userData = results.first;
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
          ..userCode = (userData['userCode'] == null || userData['userCode'] == '' || userData['userCode'] == 'null')
            ? null
            : userData['userCode'] as String;
        
        print('✅ Usuario encontrado: ${user.fullName} (${user.username})');
        return user;
      } else {
        print('❌ Usuario no encontrado o credenciales incorrectas');
        return null;
      }
    } catch (e) {
      print('❌ Error en findUser: $e');
      return null;
    }
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
    final result = await _database!.rawQuery('SELECT COUNT(*) as count FROM users WHERE userCode = ?', [code]);
    return (result.first['count'] as int) > 0;
  }

  // Obtener el siguiente ID para generar código automático
  static Future<int> getNextUserId() async {
    final result = await _database!.rawQuery('SELECT MAX(id) as maxId FROM users');
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
        ..userCode = (userData['userCode'] == null || userData['userCode'] == '' || userData['userCode'] == 'null')
            ? null
            : userData['userCode'] as String;
      return user;
    }).toList();
  }
  
  // Crear usuario
  static Future<void> createUser(User user) async {
    await _database!.insert('users', {
      'username': user.username,
      'password': user.password,
      'fullName': user.fullName,
      'role': user.role.toString().split('.').last,
      'createdAt': user.createdAt.toIso8601String(),
      'isActive': user.isActive ? 1 : 0,
      'userCode': user.userCode,
    });
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
      final results = await _database!.query('users', where: 'userCode IS NULL OR userCode = ""');
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
              userCode = 'USR-${timestamp.toString().substring(timestamp.toString().length - 4)}';
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
          print('ℹ️ Usuario ${userData['username']} es cajero, no se asigna código');
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
    final results = await _database!.query('products', where: 'isActive = ?', whereArgs: [1]);
    return results.map((productData) {
      final product = Product.fromMap(productData);
      return product;
    }).toList();
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
    
    final results = await _database!.query('products', where: whereClause, whereArgs: whereArgs);
    return results.isNotEmpty;
  }
  
  // ================== VENTAS ==================
  
  // Guardar venta
  static Future<void> saveSale(Sale sale) async {
    await _database!.insert('sales', {
      'date': sale.date.toIso8601String(),
      'total': sale.total,
      'user': sale.user,
      'paymentMethod': sale.paymentMethod,
      'items': jsonEncode(sale.items.map((item) => {
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'unit': item.unit,
      }).toList()), // Guardar como JSON string
    });

    // Descontar stock de cada producto vendido
    for (final item in sale.items) {
      // Buscar producto por nombre y unidad (ajustar si tienes código único)
      final results = await _database!.query(
        'products',
        where: 'name = ? AND unit = ? AND isActive = 1',
        whereArgs: [item.name, item.unit],
      );
      if (results.isNotEmpty) {
        final productData = results.first;
        int currentStock = productData['stock'] as int;
        int newStock = currentStock - (item.quantity as int);
        if (newStock < 0) newStock = 0;
        await _database!.update(
          'products',
          {'stock': newStock, 'updatedAt': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [productData['id']],
        );
      }
    }
  }
  
  // Obtener historial de ventas
  static Future<List<Sale>> getSales({DateTime? date, String? user}) async {
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (date != null) {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
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
      final sale = Sale()
        ..id = saleData['id'] as int
        ..date = DateTime.parse(saleData['date'] as String)
        ..total = saleData['total'] as double
        ..user = saleData['user'] as String
        ..paymentMethod = saleData['paymentMethod'] as String?
      ;
      // Parsear items desde JSON string
      try {
        final itemsString = saleData['items'] as String?;
        if (itemsString != null && itemsString.isNotEmpty) {
          final List<dynamic> itemsList = itemsString.contains('[') ? jsonDecode(itemsString) : [];
          sale.items = itemsList.map((item) => SaleItem()
            ..name = item['name']
            ..price = item['price']
            ..quantity = item['quantity']
            ..unit = item['unit']
          ).toList();
        } else {
          sale.items = [];
        }
      } catch (_) {
        sale.items = [];
      }
      return sale;
    }).toList();
  }
  
  // ================== MOVIMIENTOS DE INVENTARIO ==================
  
  // Guardar movimiento de inventario
  static Future<void> saveInventoryMovement(InventoryMovement movement) async {
    await _database!.insert('inventory_movements', {
      'productId': movement.productId,
      'type': movement.type.toString().split('.').last,
      'quantity': movement.quantity,
      'reason': movement.reason.toString().split('.').last,
      'observations': movement.observations,
      'date': movement.date.toIso8601String(),
      'userId': movement.userId,
    });
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
        observations: movementData['observations'] as String?,
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
      await _database!.execute("ALTER TABLE products ADD COLUMN isWeighted INTEGER NOT NULL DEFAULT 0");
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
      await _database!.execute('ALTER TABLE products ADD COLUMN pricePerKg REAL');
      print('✅ Migración: Campo pricePerKg agregado a la tabla products');
    } else {
      print('ℹ️ La tabla products ya tiene el campo pricePerKg');
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
      await _database!.execute('ALTER TABLE products ADD COLUMN minWeight REAL');
      print('✅ Migración: Campo minWeight agregado a la tabla products');
    }
    if (!hasMaxWeight) {
      await _database!.execute('ALTER TABLE products ADD COLUMN maxWeight REAL');
      print('✅ Migración: Campo maxWeight agregado a la tabla products');
    }
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
    
    return results.map((customerData) => Customer.fromMap(customerData)).toList();
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
  static Future<void> updateCustomerPoints(int customerId, int points) async {
    final tempCustomer = Customer(
      name: '', // Campo temporal
      email: '', // Campo temporal
      phone: '', // Campo temporal
      createdAt: DateTime.now(), // Campo temporal
      updatedAt: DateTime.now(), // Campo temporal
      points: points,
    );
    
    await _database!.update(
      'customers',
      {
        'points': points,
        'membershipLevel': tempCustomer.calculateMembershipLevel(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }
  
  // Actualizar total de compras del cliente
  static Future<void> updateCustomerTotalPurchases(int customerId, double total) async {
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
    final List<Map<String, dynamic>> results = await _database!.query('company_config');
    return results.map((configData) => CompanyConfig.fromMap(configData)).toList();
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
  static Future<List<Client>> searchClientsByBusinessName(String businessName) async {
    final results = await _database!.query(
      'clients',
      where: 'businessName LIKE ? AND isActive = ?',
      whereArgs: ['%$businessName%', 1],
      orderBy: 'businessName ASC',
    );
    
    return results.map((clientData) => Client.fromMap(clientData)).toList();
  }
  
  // Verificar si existe un cliente con el documento dado
  static Future<bool> clientDocumentExists(String documentNumber, {int? excludeId}) async {
    String whereClause = 'documentNumber = ? AND isActive = ?';
    List<dynamic> whereArgs = [documentNumber.trim(), 1];
    
    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }
    
    final results = await _database!.query('clients', where: whereClause, whereArgs: whereArgs);
    return results.isNotEmpty;
  }
} 