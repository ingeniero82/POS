import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/product.dart';
import 'sqlite_database_service.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:developer' as developer;

class ImportService {
  static const List<String> _priceWithIvaAliases = [
    'precio con iva',
    'precio_con_iva',
    'precioconiva',
    'price with vat',
    'price_with_vat',
    'pricewithvat',
    'price with tax',
    'price_with_tax',
    'pricewithtax',
  ];

  static const List<String> _ivaPercentageAliases = [
    'iva',
    'iva%',
    'iva %',
    'porcentaje iva',
    'porcentaje de iva',
    'iva porcentaje',
    'iva percentage',
    'tax',
    'vat',
    'tax rate',
    'vat rate',
  ];

  static Future<List<Product>> importProductsFromFile() async {
    try {
      // Seleccionar archivo Excel o CSV
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        allowMultiple: false,
      );

      if (result == null) {
        throw Exception('No se seleccionó ningún archivo');
      }

      File file = File(result.files.single.path!);
      String extension = file.path.split('.').last.toLowerCase();
      List<Product> products = [];

      if (extension == 'csv') {
        final csvString = await file.readAsString();
        // Detección automática de separador
        String separator = ',';
        if (csvString.contains(';') && csvString.split(';').length > csvString.split(',').length) {
          separator = ';';
        }
        final csvRows = const CsvToListConverter(fieldDelimiter: ',', eol: '\n', shouldParseNumbers: false)
          .convert(csvString.replaceAll(separator, ','));
        if (csvRows.isEmpty) return [];
        // Buscar encabezados
        final headers = csvRows[0].map((e) => e.toString().toLowerCase().trim()).toList();
        for (int i = 1; i < csvRows.length; i++) {
          final row = csvRows[i];
          if (row.length < 2) continue;
          final product = _createProductFromCsvRow(row, headers);
          if (product != null) products.add(product);
        }
      } else {
        // Excel
        var bytes = file.readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);
        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table]!;
          int headerRow = -1;
          for (int row = 0; row < sheet.maxRows; row++) {
            var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
            if (cell.value != null && cell.value.toString().toLowerCase().contains('código')) {
              headerRow = row;
              break;
            }
          }
          if (headerRow == -1) continue;
          Map<String, int> columnMap = {};
          for (int col = 0; col < sheet.maxCols; col++) {
            var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: headerRow));
            if (cell.value != null) {
              String header = cell.value.toString().toLowerCase().trim();
              columnMap[header] = col;
            }
          }
          for (int row = headerRow + 1; row < sheet.maxRows; row++) {
            try {
              Product? product = _createProductFromRow(sheet, row, columnMap);
              if (product != null) {
                products.add(product);
              }
            } catch (e) {
              developer.log('Error procesando fila $row: $e', name: 'ImportService');
            }
          }
        }
      }
      return products;
    } catch (e) {
      throw Exception('Error al importar archivo: $e');
    }
  }

  /// Solo usa columna explícita; si va vacía, no se inventa código corto (queda null en BD).
  static String? _shortCodeFromImport(String? explicit) {
    final t = explicit?.trim() ?? '';
    if (t.isEmpty) return null;
    return t;
  }

  /// Normaliza encabezado para comparar (minúsculas, sin tildes, espacios simples).
  static String _normalizeHeader(String raw) {
    var s = raw.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    const map = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ñ': 'n',
    };
    map.forEach((k, v) => s = s.replaceAll(k, v));
    return s.replaceAll('.', '').replaceAll('_', ' ');
  }

  /// Detecta columnas tipo "código corto", "ref", etc. (más flexible que igualdad exacta).
  static bool _headerIsShortCodeColumn(String rawHeader) {
    final h = _normalizeHeader(rawHeader);
    if (h.isEmpty) return false;
    const exact = [
      'codigo corto',
      'codigocorto',
      'shortcode',
      'short code',
      'corto',
      'ref',
      'referencia',
      'sku corto',
      'skucorto',
    ];
    if (exact.contains(h)) return true;
    if (h.contains('corto') &&
        (h.contains('cod') || h.contains('cód') || h.contains('sku'))) {
      return true;
    }
    return false;
  }

  static Map<String, int> _buildNormalizedIndex(List<String> headers) {
    final map = <String, int>{};
    for (int i = 0; i < headers.length; i++) {
      map[_normalizeHeader(headers[i])] = i;
    }
    return map;
  }

  static String? _getCsvByAliases(
    List row,
    Map<String, int> normalizedHeaderIndex,
    List<String> aliases,
  ) {
    for (final alias in aliases) {
      final idx = normalizedHeaderIndex[_normalizeHeader(alias)];
      if (idx == null || idx >= row.length) continue;
      final value = row[idx]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _getExcelByAliases(
    Sheet sheet,
    int row,
    Map<String, int> normalizedColumnMap,
    List<String> aliases,
  ) {
    for (final alias in aliases) {
      final colIndex = normalizedColumnMap[_normalizeHeader(alias)];
      if (colIndex == null) continue;
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: row),
      );
      final value = cell.value?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static int _resolveIvaPercentage(String? value) {
    if (value == null || value.trim().isEmpty) return 19;
    final cleaned = value.trim().replaceAll('%', '').replaceAll(',', '.');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return 19;
    return parsed.round();
  }

  static double _resolveBasePrice({
    required String? basePriceRaw,
    required String? priceWithIvaRaw,
    required int ivaPercentage,
  }) {
    final priceWithIva = _parseDouble(priceWithIvaRaw);
    if (priceWithIva != null) {
      final denominator = 1 + (ivaPercentage / 100);
      if (denominator > 0) {
        return priceWithIva / denominator;
      }
      return priceWithIva;
    }
    return _parseDouble(basePriceRaw) ?? 0.0;
  }

  static String? _shortCodeFromCsv(List<String> headers, List row) {
    for (int i = 0; i < headers.length; i++) {
      if (!_headerIsShortCodeColumn(headers[i].toString())) continue;
      if (i >= row.length) continue;
      final v = row[i]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  static String? _shortCodeFromExcel(
      Map<String, int> columnMap, Sheet sheet, int row) {
    for (final e in columnMap.entries) {
      if (!_headerIsShortCodeColumn(e.key)) continue;
      final cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: e.value, rowIndex: row));
      final v = cell.value?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  static Product? _createProductFromCsvRow(List row, List<String> headers) {
    final normalizedHeaderIndex = _buildNormalizedIndex(headers);
    String? get(List<String> aliases) =>
        _getCsvByAliases(row, normalizedHeaderIndex, aliases);

    String? code = get(['código', 'code', 'codigo']);
    String? name = get(['nombre', 'name', 'producto']);
    String? basePriceStr = get(['precio', 'price']);
    String? priceWithIvaStr = get(_priceWithIvaAliases);
    String? stockStr = get(['stock', 'cantidad', 'inventario']);
    final ivaPercentage = _resolveIvaPercentage(get(_ivaPercentageAliases));
    if (code == null || code.isEmpty || name == null || name.isEmpty) {
      return null;
    }
    
    // Campos para productos pesados
    bool isWeighted =
        _parseBool(get(['es_pesado', 'espesado', 'isweighted'])) ?? false;
    double? pricePerKg = _parseDouble(
      get(['precio_por_kg', 'precioporkg', 'priceperkg']),
    );
    double? minWeight = _parseDouble(
      get(['peso_min', 'pesomin', 'minweight']),
    );
    double? maxWeight = _parseDouble(
      get(['peso_max', 'pesomax', 'maxweight']),
    );
    
    // Asegurar que la categoría siempre tenga un valor válido
    String category = _parseGroup(
      get(['categoría', 'categoria', 'category', 'grupo', 'group']),
    );
    if (category.isEmpty || category.trim().isEmpty) {
      category = 'Otros';
    }
    
    Product product = Product(
      code: code,
      shortCode: _shortCodeFromImport(_shortCodeFromCsv(headers, row)),
      name: name,
      description: get(['descripción', 'descripcion', 'description']) ?? '',
      price: _resolveBasePrice(
        basePriceRaw: basePriceStr,
        priceWithIvaRaw: priceWithIvaStr,
        ivaPercentage: ivaPercentage,
      ),
      cost: _parseDouble(get(['costo', 'cost'])) ?? 0.0,
      stock: _parseInt(stockStr) ?? 0,
      minStock:
          _parseInt(get(['stock mínimo', 'stock_minimo', 'min_stock'])) ?? 5,
      category: category,
      unit: get(['unidad', 'unit']) ?? 'unidad',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
      ivaPercentage: ivaPercentage,
      isWeighted: isWeighted,
      pricePerKg: pricePerKg,
      minWeight: minWeight,
      maxWeight: maxWeight,
    );
    return product;
  }

  static Product? _createProductFromRow(Sheet sheet, int row, Map<String, int> columnMap) {
    final normalizedColumnMap = <String, int>{};
    for (final entry in columnMap.entries) {
      normalizedColumnMap[_normalizeHeader(entry.key)] = entry.value;
    }

    String? getCellValue(List<String> aliases) =>
        _getExcelByAliases(sheet, row, normalizedColumnMap, aliases);
    
    // Obtener valores requeridos
    String? code = getCellValue(['código', 'code', 'codigo']);
    String? name = getCellValue(['nombre', 'name', 'producto']);
    String? basePriceStr = getCellValue(['precio', 'price']);
    String? priceWithIvaStr = getCellValue(_priceWithIvaAliases);
    String? stockStr = getCellValue(['stock', 'cantidad', 'inventario']);
    final ivaPercentage =
        _resolveIvaPercentage(getCellValue(_ivaPercentageAliases));
    
    // Validar campos requeridos
    if (code == null || code.isEmpty || name == null || name.isEmpty) {
      return null;
    }
    
    // Campos para productos pesados
    bool isWeighted =
        _parseBool(getCellValue(['es_pesado', 'espesado', 'isweighted'])) ??
            false;
    double? pricePerKg = _parseDouble(
      getCellValue(['precio_por_kg', 'precioporkg', 'priceperkg']),
    );
    double? minWeight = _parseDouble(
      getCellValue(['peso_min', 'pesomin', 'minweight']),
    );
    double? maxWeight = _parseDouble(
      getCellValue(['peso_max', 'pesomax', 'maxweight']),
    );
    
    // Asegurar que la categoría siempre tenga un valor válido
    String category = _parseGroup(
      getCellValue(['categoría', 'categoria', 'category', 'grupo', 'group']),
    );
    if (category.isEmpty || category.trim().isEmpty) {
      category = 'Otros';
    }
    
    // Crear producto
    Product product = Product(
      code: code,
      shortCode: _shortCodeFromImport(_shortCodeFromExcel(columnMap, sheet, row)),
      name: name,
      description:
          getCellValue(['descripción', 'descripcion', 'description']) ?? '',
      price: _resolveBasePrice(
        basePriceRaw: basePriceStr,
        priceWithIvaRaw: priceWithIvaStr,
        ivaPercentage: ivaPercentage,
      ),
      cost: _parseDouble(getCellValue(['costo', 'cost'])) ?? 0.0,
      stock: _parseInt(stockStr) ?? 0,
      minStock: _parseInt(
            getCellValue(['stock mínimo', 'stock_minimo', 'min_stock']),
          ) ??
          5,
      category: category,
      unit: getCellValue(['unidad', 'unit']) ?? 'unidad',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
      ivaPercentage: ivaPercentage,
      isWeighted: isWeighted,
      pricePerKg: pricePerKg,
      minWeight: minWeight,
      maxWeight: maxWeight,
    );
    
    return product;
  }
  
  static double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return double.parse(value.replaceAll(',', '.'));
    } catch (e) {
      return null;
    }
  }
  
  static int? _parseInt(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return int.parse(value);
    } catch (e) {
      return null;
    }
  }
  
  static bool? _parseBool(String? value) {
    if (value == null || value.isEmpty) return null;
    String lowerValue = value.toLowerCase().trim();
    return lowerValue == 'true' || lowerValue == '1' || lowerValue == 'yes' || lowerValue == 'si';
  }
  
  static String _parseGroup(String? group) {
    if (group == null) return 'Otros';
    
    String grp = group.toLowerCase().trim();
    
    switch (grp) {
      case 'frutas':
      case 'verduras':
      case 'frutas y verduras':
        return 'Frutas y Verduras';
      case 'lácteos':
      case 'lacteos':
      case 'leche':
        return 'Lácteos';
      case 'panadería':
      case 'panaderia':
      case 'pan':
        return 'Panadería';
      case 'carnes':
      case 'carne':
        return 'Carnes';
      case 'bebidas':
      case 'bebida':
        return 'Bebidas';
      case 'abarrotes':
      case 'abarrote':
        return 'Abarrotes';
      case 'limpieza':
      case 'productos de limpieza':
        return 'Limpieza';
      case 'cuidado personal':
      case 'higiene':
        return 'Cuidado Personal';
      default:
        return 'Otros';
    }
  }
  
  static Future<void> saveImportedProducts(List<Product> products) async {
    try {
      for (Product product in products) {
        // Verificar si ya existe un producto con el mismo código
        final exists = await SQLiteDatabaseService.existsProductCode(product.code);
        if (exists) {
          // Si existe, obtener todos los productos y encontrar el que coincida
          final allProducts = await SQLiteDatabaseService.getAllProducts();
          final existing = allProducts.firstWhere(
            (p) => p.code == product.code,
            orElse: () => product,
          );
          if (existing.id != null) {
            product.id = existing.id;
            // Reimportación por etapas: celda de corto vacía no borra un corto ya guardado.
            if (product.shortCode == null && existing.shortCode != null) {
              product.shortCode = existing.shortCode;
            }
            await SQLiteDatabaseService.updateProduct(product);
          }
        } else {
          // Crear nuevo producto
          await SQLiteDatabaseService.createProduct(product);
        }
      }
    } catch (e) {
      throw Exception('Error al guardar productos: $e');
    }
  }
  
  static String getExcelTemplate() {
    return '''
CÓDIGO	CÓDIGO CORTO	NOMBRE	DESCRIPCIÓN	PRECIO	PRECIO_CON_IVA	IVA_%	COSTO	STOCK	STOCK MÍNIMO	CATEGORÍA	UNIDAD	ES_PESADO	PRECIO_POR_KG	PESO_MIN	PESO_MAX
PROD001	MZ001	Manzana Roja	Manzana roja fresca	1.50	1.79	19	1.00	100	10	Frutas y Verduras	kg	true	1.50	0.1	5.0
PROD002	LC001	Leche Entera	Leche entera 1L	2.50	2.98	19	2.00	50	5	Lácteos	litro	false	0.00	0.0	0.0
PROD003	PN001	Pan Integral	Pan integral fresco	0.80	0.95	19	0.60	200	20	Panadería	unidad	false	0.00	0.0	0.0
PROD004	CC001	Coca Cola	Coca Cola 500ml	1.20	1.43	19	0.90	150	15	Bebidas	unidad	false	0.00	0.0	0.0
PROD005	AR001	Arroz	Arroz blanco 1kg	3.00	3.57	19	2.50	80	8	Abarrotes	kg	false	0.00	0.0	0.0
PROD006	DT001	Detergente	Detergente líquido	4.50	5.36	19	3.50	30	3	Limpieza	unidad	false	0.00	0.0	0.0
PROD007	JB001	Jabón	Jabón de baño	1.80	2.14	19	1.40	60	6	Cuidado Personal	unidad	false	0.00	0.0	0.0
PROD008	PL001	Pollo	Pollo entero	8.00	9.52	19	6.50	25	3	Carnes	kg	true	8.00	0.5	3.0
PROD009	QS001	Queso	Queso fresco	5.00	5.95	19	4.00	40	4	Lácteos	kg	true	5.00	0.1	2.0
PROD010	TM001	Tomate	Tomate fresco	2.00	2.38	19	1.60	70	7	Frutas y Verduras	kg	true	2.00	0.1	1.0
''';
  }

  static Future<void> exportProductsToCsv(List<Product> products, String filePath) async {
    List<List<dynamic>> rows = [];
    
    // Encabezados mejorados para Excel
    rows.add([
      'CÓDIGO', 'CÓDIGO CORTO', 'NOMBRE', 'DESCRIPCIÓN', 'PRECIO', 'PRECIO_CON_IVA', 'IVA_%', 'COSTO', 'STOCK', 'STOCK MÍNIMO', 'CATEGORÍA', 'UNIDAD', 'ES_PESADO', 'PRECIO_POR_KG', 'PESO_MIN', 'PESO_MAX'
    ]);
    
    for (final p in products) {
      final priceWithIva = p.ivaPercentage > 0
          ? p.price * (1 + (p.ivaPercentage / 100))
          : p.price;
      rows.add([
        p.code,
        p.shortCode ?? '',
        p.name,
        p.description,
        // Formatear precios para Excel (sin decimales si son enteros)
        p.price == p.price.toInt() ? p.price.toInt() : p.price,
        priceWithIva == priceWithIva.toInt()
            ? priceWithIva.toInt()
            : priceWithIva,
        p.ivaPercentage,
        p.cost == p.cost.toInt() ? p.cost.toInt() : p.cost,
        p.stock,
        p.minStock,
        p.category,
        p.unit,
        // Convertir boolean a texto más amigable
        p.isWeighted ? 'SÍ' : 'NO',
        // Formatear precios por kg
        p.pricePerKg != null && p.pricePerKg! > 0 
            ? (p.pricePerKg == p.pricePerKg!.toInt() ? p.pricePerKg!.toInt() : p.pricePerKg!)
            : '',
        // Formatear pesos (mostrar solo si son productos pesados)
        p.isWeighted && p.minWeight != null && p.minWeight! > 0 ? p.minWeight : '',
        p.isWeighted && p.maxWeight != null && p.maxWeight! > 0 ? p.maxWeight : '',
      ]);
    }
    
    // Crear CSV con mejor formato para Excel
    String csv = const ListToCsvConverter().convert(rows);
    
    // Agregar BOM (Byte Order Mark) para mejor compatibilidad con Excel
    final bom = utf8.encode('\uFEFF');
    final file = File(filePath);
    await file.writeAsBytes([...bom, ...utf8.encode(csv)]);
  }

  /// El diálogo "Guardar como" a veces devuelve la ruta sin extensión si el usuario cambia el nombre;
  /// sin `.xlsx` Windows muestra el archivo como genérico y Excel no lo abre bien.
  static String _ensureXlsxOutputPath(String filePath) {
    final trimmed = filePath.trim();
    final ext = p.extension(trimmed).toLowerCase();
    if (ext == '.xlsx') return trimmed;
    if (ext == '.xls' || ext == '.csv') {
      return p.join(p.dirname(trimmed), '${p.basenameWithoutExtension(trimmed)}.xlsx');
    }
    return '$trimmed.xlsx';
  }

  // Nueva función para exportar en formato Excel (.xlsx) con mejor formato
  static Future<void> exportProductsToExcel(List<Product> products, String filePath) async {
    try {
      final outPath = _ensureXlsxOutputPath(filePath);
      // Crear un archivo Excel real con formato visual
      var excel = Excel.createExcel();
      var sheet = excel['Productos'];
      
      // Configurar encabezados con formato
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'CÓDIGO';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = 'CÓDIGO CORTO';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value = 'NOMBRE';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value = 'DESCRIPCIÓN';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0)).value = 'PRECIO';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0)).value = 'PRECIO_CON_IVA';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0)).value = 'IVA_%';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0)).value = 'COSTO';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 0)).value = 'STOCK';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 0)).value = 'STOCK MÍNIMO';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 0)).value = 'CATEGORÍA';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 0)).value = 'UNIDAD';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 0)).value = 'ES_PESADO';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: 0)).value = 'PRECIO_POR_KG';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: 0)).value = 'PESO_MIN';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: 0)).value = 'PESO_MAX';
      
      // Llenar datos de productos
      for (int i = 0; i < products.length; i++) {
        final p = products[i];
        final row = i + 1;
        final priceWithIva = p.ivaPercentage > 0
            ? p.price * (1 + (p.ivaPercentage / 100))
            : p.price;
        
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = p.code;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
            p.shortCode ?? '';
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = p.name;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = p.description;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = p.price;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = priceWithIva;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = p.ivaPercentage;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = p.cost;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = p.stock;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = p.minStock;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = p.category;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row)).value = p.unit;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row)).value = p.isWeighted ? 'SÍ' : 'NO';
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row)).value = p.pricePerKg ?? '';
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: row)).value = p.minWeight ?? '';
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: row)).value = p.maxWeight ?? '';
      }
      
      // Ajustar ancho de columnas automáticamente
      for (int i = 0; i < 16; i++) {
        // Nota: setColumnWidth no está disponible en esta versión
        // Las columnas se ajustarán automáticamente en Excel
      }
      
      // Guardar archivo Excel
      final bytes = excel.encode();
      if (bytes != null) {
        final file = File(outPath);
        await file.writeAsBytes(bytes);
      } else {
        throw Exception('Error al generar archivo Excel');
      }
      
    } catch (e) {
      throw Exception('Error al exportar a Excel: $e');
    }
  }

} 