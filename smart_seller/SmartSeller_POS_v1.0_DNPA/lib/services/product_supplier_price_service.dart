import '../models/product_supplier_price.dart';
import 'sqlite_database_service.dart';

/// Fase 1: precio de compra por producto y proveedor (sin historial).
class ProductSupplierPriceService {
  static const String _table = 'product_supplier_prices';

  /// Patrón LIKE seguro (quita % y _ del texto para no usar comodines accidentales).
  static String _likeArg(String query) {
    final t = query.trim();
    if (t.isEmpty) return '%';
    final safe = t.replaceAll('%', '').replaceAll('_', '');
    if (safe.isEmpty) return '%';
    return '%$safe%';
  }

  static Future<int> create(ProductSupplierPrice row) async {
    final db = SQLiteDatabaseService.database;
    if (db == null) throw Exception('Base de datos no inicializada');
    final now = DateTime.now();
    final map = row.toMapForInsert();
    map['updated_at'] = now.toIso8601String();
    return db.insert(_table, map);
  }

  /// Inserta o actualiza el precio para el par (producto, proveedor).
  static Future<int> upsert(ProductSupplierPrice row) async {
    final db = SQLiteDatabaseService.database;
    if (db == null) throw Exception('Base de datos no inicializada');
    final now = DateTime.now();
    final existing = await getByProductAndSupplier(
      row.productId,
      row.supplierId,
    );
    if (existing != null && existing.id != null) {
      await db.update(
        _table,
        {
          'supplier_reference': row.supplierReference,
          'purchase_price': row.purchasePrice,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return existing.id!;
    }
    return create(row.copyWith(updatedAt: now));
  }

  static Future<bool> update(ProductSupplierPrice row) async {
    final db = SQLiteDatabaseService.database;
    if (db == null) throw Exception('Base de datos no inicializada');
    if (row.id == null) return false;
    final n = await db.update(
      _table,
      {
        'supplier_reference': row.supplierReference,
        'purchase_price': row.purchasePrice,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [row.id],
    );
    return n > 0;
  }

  static Future<bool> deleteById(int id) async {
    final db = SQLiteDatabaseService.database;
    if (db == null) throw Exception('Base de datos no inicializada');
    final n = await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    return n > 0;
  }

  static Future<ProductSupplierPrice?> getById(int id) async {
    final db = SQLiteDatabaseService.database;
    if (db == null) return null;
    final maps = await db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ProductSupplierPrice.fromMap(maps.first);
  }

  static Future<ProductSupplierPrice?> getByProductAndSupplier(
    int productId,
    int supplierId,
  ) async {
    final db = SQLiteDatabaseService.database;
    if (db == null) return null;
    final maps = await db.query(
      _table,
      where: 'product_id = ? AND supplier_id = ?',
      whereArgs: [productId, supplierId],
    );
    if (maps.isEmpty) return null;
    return ProductSupplierPrice.fromMap(maps.first);
  }

  static Future<List<ProductSupplierPriceDetail>> listByProduct(
    int productId,
  ) async {
    final db = SQLiteDatabaseService.database;
    if (db == null) return [];
    final rows = await db.rawQuery(
      '''
      SELECT
        psp.id,
        psp.product_id,
        psp.supplier_id,
        psp.supplier_reference,
        psp.purchase_price,
        psp.updated_at,
        p.code AS product_code,
        p.shortCode AS product_short_code,
        p.name AS product_name,
        s.name AS supplier_name
      FROM $_table psp
      INNER JOIN products p ON p.id = psp.product_id AND p.isActive = 1
      INNER JOIN suppliers s ON s.id = psp.supplier_id AND s.is_active = 1
      WHERE psp.product_id = ?
      ORDER BY s.name ASC
      ''',
      [productId],
    );
    return rows.map(ProductSupplierPriceDetail.fromJoinedMap).toList();
  }

  static Future<List<ProductSupplierPriceDetail>> listBySupplier(
    int supplierId,
  ) async {
    final db = SQLiteDatabaseService.database;
    if (db == null) return [];
    final rows = await db.rawQuery(
      '''
      SELECT
        psp.id,
        psp.product_id,
        psp.supplier_id,
        psp.supplier_reference,
        psp.purchase_price,
        psp.updated_at,
        p.code AS product_code,
        p.shortCode AS product_short_code,
        p.name AS product_name,
        s.name AS supplier_name
      FROM $_table psp
      INNER JOIN products p ON p.id = psp.product_id AND p.isActive = 1
      INNER JOIN suppliers s ON s.id = psp.supplier_id AND s.is_active = 1
      WHERE psp.supplier_id = ?
      ORDER BY p.name ASC
      ''',
      [supplierId],
    );
    return rows.map(ProductSupplierPriceDetail.fromJoinedMap).toList();
  }

  /// Listado reciente (para pantalla principal). Orden por última actualización.
  static Future<List<ProductSupplierPriceDetail>> listAll({int limit = 1000}) async {
    final db = SQLiteDatabaseService.database;
    if (db == null) return [];
    final rows = await db.rawQuery(
      '''
      SELECT
        psp.id,
        psp.product_id,
        psp.supplier_id,
        psp.supplier_reference,
        psp.purchase_price,
        psp.updated_at,
        p.code AS product_code,
        p.shortCode AS product_short_code,
        p.name AS product_name,
        s.name AS supplier_name
      FROM $_table psp
      INNER JOIN products p ON p.id = psp.product_id AND p.isActive = 1
      INNER JOIN suppliers s ON s.id = psp.supplier_id AND s.is_active = 1
      ORDER BY psp.updated_at DESC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(ProductSupplierPriceDetail.fromJoinedMap).toList();
  }

  /// Busca por código o nombre de producto, referencia del proveedor o nombre del proveedor.
  /// [query] vacío devuelve lista vacía (use [listByProduct] / [listBySupplier] para listar todo).
  static Future<List<ProductSupplierPriceDetail>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final db = SQLiteDatabaseService.database;
    if (db == null) return [];

    final pattern = _likeArg(q);
    final rows = await db.rawQuery(
      '''
      SELECT
        psp.id,
        psp.product_id,
        psp.supplier_id,
        psp.supplier_reference,
        psp.purchase_price,
        psp.updated_at,
        p.code AS product_code,
        p.shortCode AS product_short_code,
        p.name AS product_name,
        s.name AS supplier_name
      FROM $_table psp
      INNER JOIN products p ON p.id = psp.product_id AND p.isActive = 1
      INNER JOIN suppliers s ON s.id = psp.supplier_id AND s.is_active = 1
      WHERE
        p.code LIKE ?
        OR p.shortCode LIKE ?
        OR p.name LIKE ?
        OR IFNULL(psp.supplier_reference, '') LIKE ?
        OR s.name LIKE ?
      ORDER BY p.name ASC, s.name ASC
      ''',
      [pattern, pattern, pattern, pattern, pattern],
    );
    return rows.map(ProductSupplierPriceDetail.fromJoinedMap).toList();
  }
}
