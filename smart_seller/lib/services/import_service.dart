import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import 'sqlite_database_service.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:developer' as developer;

class ImportService {
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

  static Product? _createProductFromCsvRow(List row, List<String> headers) {
    String? get(String name) {
      int idx = headers.indexWhere((h) => h == name.toLowerCase());
      if (idx == -1 || idx >= row.length) return null;
      return row[idx]?.toString().trim();
    }
    String? code = get('código') ?? get('code') ?? get('codigo');
    String? name = get('nombre') ?? get('name') ?? get('producto');
    String? priceStr = get('precio') ?? get('price');
    String? stockStr = get('stock') ?? get('cantidad') ?? get('inventario');
    if (code == null || code.isEmpty || name == null || name.isEmpty) {
      return null;
    }
    
    // Campos para productos pesados
    bool isWeighted = _parseBool(get('es_pesado') ?? get('espesado') ?? get('isweighted')) ?? false;
    double? pricePerKg = _parseDouble(get('precio_por_kg') ?? get('precioporkg') ?? get('priceperkg'));
    double? minWeight = _parseDouble(get('peso_min') ?? get('pesomin') ?? get('minweight'));
    double? maxWeight = _parseDouble(get('peso_max') ?? get('pesomax') ?? get('maxweight'));
    
    Product product = Product(
      code: code,
      shortCode: code.length > 8 ? code.substring(0, 8) : code,
      name: name,
      description: get('descripción') ?? get('descripcion') ?? get('description') ?? '',
      price: _parseDouble(priceStr) ?? 0.0,
      cost: _parseDouble(get('costo') ?? get('cost')) ?? 0.0,
      stock: _parseInt(stockStr) ?? 0,
      minStock: _parseInt(get('stock mínimo') ?? get('stock_minimo') ?? get('min_stock')) ?? 5,
      category: _parseCategory(get('categoría') ?? get('categoria') ?? get('category')),
      unit: get('unidad') ?? get('unit') ?? 'unidad',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
      isWeighted: isWeighted,
      pricePerKg: pricePerKg,
      minWeight: minWeight,
      maxWeight: maxWeight,
    );
    return product;
  }

  static Product? _createProductFromRow(Sheet sheet, int row, Map<String, int> columnMap) {
    // Obtener valores de las celdas
    String? getCellValue(String columnName) {
      int? colIndex = columnMap[columnName];
      if (colIndex == null) return null;
      
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: row));
      return cell.value?.toString().trim();
    }
    
    // Obtener valores requeridos
    String? code = getCellValue('código') ?? getCellValue('code') ?? getCellValue('codigo');
    String? name = getCellValue('nombre') ?? getCellValue('name') ?? getCellValue('producto');
    String? priceStr = getCellValue('precio') ?? getCellValue('price');
    String? stockStr = getCellValue('stock') ?? getCellValue('cantidad') ?? getCellValue('inventario');
    
    // Validar campos requeridos
    if (code == null || code.isEmpty || name == null || name.isEmpty) {
      return null;
    }
    
    // Campos para productos pesados
    bool isWeighted = _parseBool(getCellValue('es_pesado') ?? getCellValue('espesado') ?? getCellValue('isweighted')) ?? false;
    double? pricePerKg = _parseDouble(getCellValue('precio_por_kg') ?? getCellValue('precioporkg') ?? getCellValue('priceperkg'));
    double? minWeight = _parseDouble(getCellValue('peso_min') ?? getCellValue('pesomin') ?? getCellValue('minweight'));
    double? maxWeight = _parseDouble(getCellValue('peso_max') ?? getCellValue('pesomax') ?? getCellValue('maxweight'));
    
    // Crear producto
    Product product = Product(
      code: code,
      shortCode: code.length > 8 ? code.substring(0, 8) : code,
      name: name,
      description: getCellValue('descripción') ?? getCellValue('descripcion') ?? getCellValue('description') ?? '',
      price: _parseDouble(priceStr) ?? 0.0,
      cost: _parseDouble(getCellValue('costo') ?? getCellValue('cost')) ?? 0.0,
      stock: _parseInt(stockStr) ?? 0,
      minStock: _parseInt(getCellValue('stock mínimo') ?? getCellValue('stock_minimo') ?? getCellValue('min_stock')) ?? 5,
      category: _parseCategory(getCellValue('categoría') ?? getCellValue('categoria') ?? getCellValue('category')),
      unit: getCellValue('unidad') ?? getCellValue('unit') ?? 'unidad',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
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
  
  static ProductCategory _parseCategory(String? category) {
    if (category == null) return ProductCategory.otros;
    
    String cat = category.toLowerCase().trim();
    
    switch (cat) {
      case 'frutas':
      case 'verduras':
      case 'frutas y verduras':
        return ProductCategory.frutasVerduras;
      case 'lácteos':
      case 'lacteos':
      case 'leche':
        return ProductCategory.lacteos;
      case 'panadería':
      case 'panaderia':
      case 'pan':
        return ProductCategory.panaderia;
      case 'carnes':
      case 'carne':
        return ProductCategory.carnes;
      case 'bebidas':
      case 'bebida':
        return ProductCategory.bebidas;
      case 'abarrotes':
      case 'abarrote':
        return ProductCategory.abarrotes;
      case 'limpieza':
      case 'productos de limpieza':
        return ProductCategory.limpieza;
      case 'cuidado personal':
      case 'higiene':
        return ProductCategory.cuidadoPersonal;
      default:
        return ProductCategory.otros;
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
            // Actualizar el producto existente
            product.id = existing.id;
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
CÓDIGO	NOMBRE	DESCRIPCIÓN	PRECIO	COSTO	STOCK	STOCK MÍNIMO	CATEGORÍA	UNIDAD	ES_PESADO	PRECIO_POR_KG	PESO_MIN	PESO_MAX
PROD001	Manzana Roja	Manzana roja fresca	1.50	1.00	100	10	Frutas y Verduras	kg	true	1.50	0.1	5.0
PROD002	Leche Entera	Leche entera 1L	2.50	2.00	50	5	Lácteos	litro	false	0.00	0.0	0.0
PROD003	Pan Integral	Pan integral fresco	0.80	0.60	200	20	Panadería	unidad	false	0.00	0.0	0.0
PROD004	Coca Cola	Coca Cola 500ml	1.20	0.90	150	15	Bebidas	unidad	false	0.00	0.0	0.0
PROD005	Arroz	Arroz blanco 1kg	3.00	2.50	80	8	Abarrotes	kg	false	0.00	0.0	0.0
PROD006	Detergente	Detergente líquido	4.50	3.50	30	3	Limpieza	unidad	false	0.00	0.0	0.0
PROD007	Jabón	Jabón de baño	1.80	1.40	60	6	Cuidado Personal	unidad	false	0.00	0.0	0.0
PROD008	Pollo	Pollo entero	8.00	6.50	25	3	Carnes	kg	true	8.00	0.5	3.0
PROD009	Queso	Queso fresco	5.00	4.00	40	4	Lácteos	kg	true	5.00	0.1	2.0
PROD010	Tomate	Tomate fresco	2.00	1.60	70	7	Frutas y Verduras	kg	true	2.00	0.1	1.0
''';
  }

  static Future<void> exportProductsToCsv(List<Product> products, String filePath) async {
    List<List<dynamic>> rows = [];
    rows.add([
      'CÓDIGO', 'NOMBRE', 'DESCRIPCIÓN', 'PRECIO', 'COSTO', 'STOCK', 'STOCK MÍNIMO', 'CATEGORÍA', 'UNIDAD', 'ES_PESADO', 'PRECIO_POR_KG', 'PESO_MIN', 'PESO_MAX'
    ]);
    for (final p in products) {
      rows.add([
        p.code,
        p.name,
        p.description,
        p.price,
        p.cost,
        p.stock,
        p.minStock,
        _categoryToString(p.category),
        p.unit,
        p.isWeighted,
        p.pricePerKg ?? 0.0,
        p.minWeight ?? 0.0,
        p.maxWeight ?? 0.0,
      ]);
    }
    String csv = const ListToCsvConverter().convert(rows);
    final file = File(filePath);
    await file.writeAsString(csv, encoding: utf8);
  }

  static String _categoryToString(ProductCategory category) {
    switch (category) {
      case ProductCategory.frutasVerduras:
        return 'Frutas y Verduras';
      case ProductCategory.lacteos:
        return 'Lácteos';
      case ProductCategory.panaderia:
        return 'Panadería';
      case ProductCategory.carnes:
        return 'Carnes';
      case ProductCategory.bebidas:
        return 'Bebidas';
      case ProductCategory.abarrotes:
        return 'Abarrotes';
      case ProductCategory.limpieza:
        return 'Limpieza';
      case ProductCategory.cuidadoPersonal:
        return 'Cuidado Personal';
      default:
        return 'Otros';
    }
  }
} 