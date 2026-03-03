import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import '../models/accounting_entry.dart';
import 'sqlite_database_service.dart';

class SupplierService {
  static const String _tableName = 'suppliers';
  static const String _paymentsTableName = 'supplier_payments';
  static const String _accountingTableName = 'accounting_entries';

  // ========== MÉTODOS PARA PROVEEDORES ==========

  // Crear proveedor
  static Future<int> createSupplier(Supplier supplier) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final result = await db.insert(_tableName, supplier.toMap());
      print('✅ Proveedor creado con ID: $result');
      return result;
    } catch (e) {
      print('❌ Error al crear proveedor: $e');
      rethrow;
    }
  }

  // Obtener todos los proveedores activos
  static Future<List<Supplier>> getAllSuppliers() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'name ASC',
      );

      return List.generate(maps.length, (i) => Supplier.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al obtener proveedores: $e');
      return [];
    }
  }

  // Buscar proveedores por nombre o documento
  static Future<List<Supplier>> searchSuppliers(String query) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'is_active = ? AND (name LIKE ? OR document LIKE ?)',
        whereArgs: [1, '%$query%', '%$query%'],
        orderBy: 'name ASC',
      );

      return List.generate(maps.length, (i) => Supplier.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al buscar proveedores: $e');
      return [];
    }
  }

  // Obtener proveedor por ID
  static Future<Supplier?> getSupplierById(int id) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'id = ? AND is_active = ?',
        whereArgs: [id, 1],
      );

      if (maps.isNotEmpty) {
        return Supplier.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('❌ Error al obtener proveedor por ID: $e');
      return null;
    }
  }

  // Actualizar proveedor
  static Future<bool> updateSupplier(Supplier supplier) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final result = await db.update(
        _tableName,
        supplier.toMap(),
        where: 'id = ?',
        whereArgs: [supplier.id],
      );

      print('✅ Proveedor actualizado: ${result > 0}');
      return result > 0;
    } catch (e) {
      print('❌ Error al actualizar proveedor: $e');
      return false;
    }
  }

  // Eliminar proveedor (soft delete)
  static Future<bool> deleteSupplier(int id) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final result = await db.update(
        _tableName,
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );

      print('✅ Proveedor eliminado: ${result > 0}');
      return result > 0;
    } catch (e) {
      print('❌ Error al eliminar proveedor: $e');
      return false;
    }
  }

  // ========== MÉTODOS PARA PAGOS DE PROVEEDORES ==========

  // Crear pago a proveedor
  static Future<int> createSupplierPayment(SupplierPayment payment) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final result = await db.insert(_paymentsTableName, payment.toMap());
      
      // Crear entrada contable automáticamente
      await createAccountingEntry(AccountingEntry(
        type: 'expense',
        amount: payment.amount,
        description: 'Pago a proveedor: ${payment.description ?? 'Sin descripción'}',
        category: 'Pago a Proveedores', // ✅ Traducido a español
        date: payment.paymentDate,
        userId: payment.userId,
        createdAt: DateTime.now(),
      ));

      print('✅ Pago a proveedor creado con ID: $result');
      return result;
    } catch (e) {
      print('❌ Error al crear pago a proveedor: $e');
      rethrow;
    }
  }

  // Obtener pagos de un proveedor
  static Future<List<SupplierPayment>> getSupplierPayments(int supplierId) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _paymentsTableName,
        where: 'supplier_id = ? AND is_active = ?',
        whereArgs: [supplierId, 1],
        orderBy: 'payment_date DESC',
      );

      return List.generate(maps.length, (i) => SupplierPayment.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al obtener pagos de proveedor: $e');
      return [];
    }
  }

  // Obtener todos los pagos
  static Future<List<SupplierPayment>> getAllSupplierPayments() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _paymentsTableName,
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'payment_date DESC',
      );

      return List.generate(maps.length, (i) => SupplierPayment.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al obtener todos los pagos: $e');
      return [];
    }
  }

  // ========== MÉTODOS PARA CONTABILIDAD ==========

  // Crear entrada contable
  static Future<int> createAccountingEntry(AccountingEntry entry) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final result = await db.insert(_accountingTableName, entry.toMap());
      print('✅ Entrada contable creada con ID: $result');
      return result;
    } catch (e) {
      print('❌ Error al crear entrada contable: $e');
      rethrow;
    }
  }

  // Obtener entradas contables por fecha
  static Future<List<AccountingEntry>> getAccountingEntriesByDate(DateTime date) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final List<Map<String, dynamic>> maps = await db.query(
        _accountingTableName,
        where: 'date >= ? AND date <= ? AND is_active = ?',
        whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String(), 1],
        orderBy: 'date DESC',
      );

      return List.generate(maps.length, (i) => AccountingEntry.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al obtener entradas contables: $e');
      return [];
    }
  }

  // Obtener resumen de ingresos y egresos por fecha
  static Future<Map<String, double>> getIncomeExpenseSummary(DateTime date) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT type, SUM(amount) as total
        FROM $_accountingTableName
        WHERE date >= ? AND date <= ? AND is_active = ?
        GROUP BY type
      ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String(), 1]);

      double income = 0.0;
      double expense = 0.0;

      for (var map in maps) {
        if (map['type'] == 'income') {
          income = map['total']?.toDouble() ?? 0.0;
        } else if (map['type'] == 'expense') {
          expense = map['total']?.toDouble() ?? 0.0;
        }
      }

      return {
        'income': income,
        'expense': expense,
        'net': income - expense,
      };
    } catch (e) {
      print('❌ Error al obtener resumen contable: $e');
      return {'income': 0.0, 'expense': 0.0, 'net': 0.0};
    }
  }

  // ✅ NUEVO: Obtener pagos con información de facturación
  static Future<List<Map<String, dynamic>>> getPaymentsWithInvoiceInfo() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT 
          sp.id,
          sp.amount,
          sp.payment_date,
          sp.payment_method,
          sp.description,
          sp.created_at,
          s.name as supplier_name,
          s.document as supplier_document,
          u.fullName as user_name
        FROM $_paymentsTableName sp
        JOIN $_tableName s ON sp.supplier_id = s.id
        JOIN users u ON sp.user_id = u.id
        WHERE sp.is_active = 1
        ORDER BY sp.payment_date DESC
      ''');

      return maps;
    } catch (e) {
      print('❌ Error al obtener pagos con información de facturación: $e');
      return [];
    }
  }

  // ✅ NUEVO: Buscar pagos por número de factura
  static Future<List<SupplierPayment>> searchPaymentsByInvoiceNumber(String invoiceNumber) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _paymentsTableName,
        where: 'description LIKE ? AND is_active = ?',
        whereArgs: ['%Factura: $invoiceNumber%', 1],
        orderBy: 'payment_date DESC',
      );

      return List.generate(maps.length, (i) => SupplierPayment.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al buscar pagos por número de factura: $e');
      return [];
    }
  }

  // ✅ NUEVO: Validar si un proveedor tiene datos completos para facturación electrónica
  static Map<String, dynamic> validateSupplierForElectronicInvoicing(Supplier supplier) {
    final requiredFields = <String, String>{
      'name': 'Nombre/Razón Social',
      'document': 'Número de Documento',
      'documentType': 'Tipo de Documento',
      'address': 'Dirección',
      'city': 'Ciudad',
      'department': 'Departamento',
      'country': 'País',
      'taxRegime': 'Régimen Tributario',
      'economicActivity': 'Actividad Económica',
    };

    final missingFields = <String>[];
    final completedFields = <String>[];

    for (final entry in requiredFields.entries) {
      final fieldValue = _getFieldValue(supplier, entry.key);
      if (fieldValue == null || fieldValue.toString().trim().isEmpty) {
        missingFields.add(entry.value);
      } else {
        completedFields.add(entry.value);
      }
    }

    final isComplete = missingFields.isEmpty;
    final completionPercentage = (completedFields.length / requiredFields.length * 100).round();

    return {
      'isComplete': isComplete,
      'completionPercentage': completionPercentage,
      'missingFields': missingFields,
      'completedFields': completedFields,
      'canReceiveElectronicInvoice': isComplete,
    };
  }

  // ✅ NUEVO: Obtener valor de campo dinámicamente
  static dynamic _getFieldValue(Supplier supplier, String fieldName) {
    switch (fieldName) {
      case 'name': return supplier.name;
      case 'document': return supplier.document;
      case 'documentType': return supplier.documentType;
      case 'address': return supplier.address;
      case 'city': return supplier.city;
      case 'department': return supplier.department;
      case 'country': return supplier.country;
      case 'taxRegime': return supplier.taxRegime;
      case 'economicActivity': return supplier.economicActivity;
      case 'phone': return supplier.phone;
      case 'email': return supplier.email;
      case 'postalCode': return supplier.postalCode;
      case 'contactPerson': return supplier.contactPerson;
      case 'contactPhone': return supplier.contactPhone;
      case 'contactEmail': return supplier.contactEmail;
      default: return null;
    }
  }
}
