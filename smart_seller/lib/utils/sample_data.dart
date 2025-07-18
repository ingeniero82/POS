import '../models/client.dart';
import '../models/product.dart';
import '../services/client_service.dart';
import '../services/sqlite_database_service.dart';

class SampleData {
  // Productos de ejemplo para pruebas
  static final List<Map<String, dynamic>> sampleProducts = [
    {
      'code': 'PROD001',
      'name': 'Manzana Roja',
      'description': 'Manzana roja fresca',
      'price': 1500.0,
      'cost': 1000.0,
      'stock': 100,
      'minStock': 10,
      'category': 'Frutas y Verduras',
      'unit': 'kg',
      'isWeighted': false,
    },
    {
      'code': 'PROD002',
      'name': 'Leche Entera',
      'description': 'Leche entera 1L',
      'price': 2500.0,
      'cost': 2000.0,
      'stock': 50,
      'minStock': 5,
      'category': 'Lácteos',
      'unit': 'litro',
      'isWeighted': false,
    },
    {
      'code': 'PROD003',
      'name': 'Pan Integral',
      'description': 'Pan integral fresco',
      'price': 800.0,
      'cost': 600.0,
      'stock': 200,
      'minStock': 20,
      'category': 'Panadería',
      'unit': 'unidad',
      'isWeighted': false,
    },
    {
      'code': 'PROD004',
      'name': 'Coca Cola',
      'description': 'Coca Cola 500ml',
      'price': 1200.0,
      'cost': 900.0,
      'stock': 150,
      'minStock': 15,
      'category': 'Bebidas',
      'unit': 'unidad',
      'isWeighted': false,
    },
    {
      'code': 'PROD005',
      'name': 'Arroz',
      'description': 'Arroz blanco 1kg',
      'price': 3000.0,
      'cost': 2500.0,
      'stock': 80,
      'minStock': 8,
      'category': 'Abarrotes',
      'unit': 'kg',
      'isWeighted': false,
    },
    {
      'code': 'PROD006',
      'name': 'Detergente',
      'description': 'Detergente líquido',
      'price': 4500.0,
      'cost': 3500.0,
      'stock': 30,
      'minStock': 3,
      'category': 'Limpieza',
      'unit': 'unidad',
      'isWeighted': false,
    },
    {
      'code': 'PROD007',
      'name': 'Jabón',
      'description': 'Jabón de baño',
      'price': 1800.0,
      'cost': 1400.0,
      'stock': 60,
      'minStock': 6,
      'category': 'Cuidado Personal',
      'unit': 'unidad',
      'isWeighted': false,
    },
    {
      'code': 'PROD008',
      'name': 'Pollo',
      'description': 'Pollo entero',
      'price': 8000.0,
      'cost': 6500.0,
      'stock': 25,
      'minStock': 3,
      'category': 'Carnes',
      'unit': 'kg',
      'isWeighted': true,
      'pricePerKg': 8000.0,
      'minWeight': 0.5,
      'maxWeight': 3.0,
    },
    {
      'code': 'PROD009',
      'name': 'Queso',
      'description': 'Queso fresco',
      'price': 5000.0,
      'cost': 4000.0,
      'stock': 40,
      'minStock': 4,
      'category': 'Lácteos',
      'unit': 'kg',
      'isWeighted': true,
      'pricePerKg': 5000.0,
      'minWeight': 0.1,
      'maxWeight': 2.0,
    },
    {
      'code': 'PROD010',
      'name': 'Tomate',
      'description': 'Tomate fresco',
      'price': 2000.0,
      'cost': 1600.0,
      'stock': 70,
      'minStock': 7,
      'category': 'Frutas y Verduras',
      'unit': 'kg',
      'isWeighted': false,
    },
    {
      'code': 'PROD011',
      'name': 'Plátano',
      'description': 'Plátano maduro',
      'price': 1200.0,
      'cost': 900.0,
      'stock': 120,
      'minStock': 12,
      'category': 'Frutas y Verduras',
      'unit': 'kg',
      'isWeighted': false,
    },
    {
      'code': 'PROD012',
      'name': 'Yogurt',
      'description': 'Yogurt natural',
      'price': 1800.0,
      'cost': 1400.0,
      'stock': 45,
      'minStock': 5,
      'category': 'Lácteos',
      'unit': 'unidad',
      'isWeighted': false,
    },
    {
      'code': 'PROD013',
      'name': 'Croissant',
      'description': 'Croissant fresco',
      'price': 1500.0,
      'cost': 1200.0,
      'stock': 80,
      'minStock': 8,
      'category': 'Panadería',
      'unit': 'unidad',
      'isWeighted': false,
    },
    {
      'code': 'PROD014',
      'name': 'Agua Mineral',
      'description': 'Agua mineral 500ml',
      'price': 800.0,
      'cost': 600.0,
      'stock': 200,
      'minStock': 20,
      'category': 'Bebidas',
      'unit': 'unidad',
      'isWeighted': false,
    },
    {
      'code': 'PROD015',
      'name': 'Aceite',
      'description': 'Aceite de cocina 1L',
      'price': 4000.0,
      'cost': 3200.0,
      'stock': 60,
      'minStock': 6,
      'category': 'Abarrotes',
      'unit': 'litro',
      'isWeighted': false,
    },
    // Productos adicionales que se ven en la imagen
    {
      'code': '123465446',
      'name': 'papas',
      'description': 'Papas frescas',
      'price': 2500.0,
      'cost': 2000.0,
      'stock': 83,
      'minStock': 10,
      'category': 'Frutas y Verduras',
      'unit': 'kg',
      'isWeighted': false,
    },
    {
      'code': '656545664',
      'name': 'PAN TAJADO',
      'description': 'Pan tajado',
      'price': 3600.0,
      'cost': 3000.0,
      'stock': 5,
      'minStock': 2,
      'category': 'Panadería',
      'unit': 'unidad',
      'isWeighted': false,
    },
    {
      'code': '1552445',
      'name': 'Arroz diana x 500gr',
      'description': 'Arroz diana x 500gr',
      'price': 2500.0,
      'cost': 2000.0,
      'stock': 3,
      'minStock': 2,
      'category': 'Abarrotes',
      'unit': 'unidad',
      'isWeighted': false,
    },
  ];

  // Clientes de ejemplo para pruebas
  static final List<Map<String, dynamic>> sampleClients = [
    {
      'documentType': DocumentType.nit.name,
      'documentNumber': '900123456-7',
      'businessName': 'Empresa ABC S.A.S.',
      'email': 'contacto@empresaabc.com',
      'phone': '3001234567',
      'address': 'Calle 123 #45-67, Bogotá',
      'fiscalResponsibility': FiscalResponsibility.responsableIva.name,
      'city': 'Bogotá',
      'department': 'Cundinamarca',
      'country': 'Colombia',
      'postalCode': '110111',
      'contactPerson': 'Juan Pérez',
      'notes': 'Cliente corporativo',
    },
    {
      'documentType': DocumentType.cedulaCiudadania.name,
      'documentNumber': '1234567890',
      'businessName': 'María García López',
      'email': 'maria.garcia@email.com',
      'phone': '3009876543',
      'address': 'Carrera 78 #12-34, Medellín',
      'fiscalResponsibility': FiscalResponsibility.noResponsableIva.name,
      'city': 'Medellín',
      'department': 'Antioquia',
      'country': 'Colombia',
      'postalCode': '050001',
      'contactPerson': 'María García',
      'notes': 'Cliente frecuente',
    },
    {
      'documentType': DocumentType.nit.name,
      'documentNumber': '800987654-3',
      'businessName': 'Comercial XYZ Ltda.',
      'email': 'ventas@comercialxyz.com',
      'phone': '3005551234',
      'address': 'Avenida Principal #100, Cali',
      'fiscalResponsibility': FiscalResponsibility.responsableIva.name,
      'city': 'Cali',
      'department': 'Valle del Cauca',
      'country': 'Colombia',
      'postalCode': '760001',
      'contactPerson': 'Carlos Rodríguez',
      'notes': 'Cliente mayorista',
    },
    {
      'documentType': DocumentType.cedulaCiudadania.name,
      'documentNumber': '9876543210',
      'businessName': 'Pedro Silva Martínez',
      'email': 'pedro.silva@email.com',
      'phone': '3004445678',
      'address': 'Calle 45 #67-89, Barranquilla',
      'fiscalResponsibility': FiscalResponsibility.noResponsableIva.name,
      'city': 'Barranquilla',
      'department': 'Atlántico',
      'country': 'Colombia',
      'postalCode': '080001',
      'contactPerson': 'Pedro Silva',
      'notes': 'Cliente ocasional',
    },
    {
      'documentType': DocumentType.nit.name,
      'documentNumber': '900555666-7',
      'businessName': 'Distribuidora Nacional S.A.',
      'email': 'info@distribuidoranacional.com',
      'phone': '3007778889',
      'address': 'Carrera 15 #25-35, Bucaramanga',
      'fiscalResponsibility': FiscalResponsibility.granContribuyente.name,
      'city': 'Bucaramanga',
      'department': 'Santander',
      'country': 'Colombia',
      'postalCode': '680001',
      'contactPerson': 'Ana María López',
      'notes': 'Cliente premium',
    },
  ];
  
  // Método para poblar la base de datos con clientes de ejemplo
  static Future<void> populateSampleClients() async {
    print('🔧 Poblando base de datos con clientes de ejemplo...');
    
    int createdCount = 0;
    int skippedCount = 0;
    
    for (final clientData in sampleClients) {
      try {
        // Verificar si el cliente ya existe
        final existingClient = await ClientService.findClientByDocument(clientData['documentNumber']);
        if (existingClient != null) {
          print('ℹ️ Cliente ya existe: ${clientData['businessName']}');
          skippedCount++;
          continue;
        }
        
        // Crear el cliente
        final client = await ClientService.createClient(
          documentType: clientData['documentType'],
          documentNumber: clientData['documentNumber'],
          businessName: clientData['businessName'],
          email: clientData['email'],
          phone: clientData['phone'],
          address: clientData['address'],
          fiscalResponsibility: clientData['fiscalResponsibility'],
          city: clientData['city'],
          department: clientData['department'],
          country: clientData['country'],
          postalCode: clientData['postalCode'],
          contactPerson: clientData['contactPerson'],
          notes: clientData['notes'],
        );
        
        if (client != null) {
          print('✅ Cliente creado: ${client.businessName}');
          createdCount++;
        }
      } catch (e) {
        print('❌ Error al crear cliente ${clientData['businessName']}: $e');
      }
    }
    
    print('📊 Resumen de población de datos:');
    print('   ✅ Clientes creados: $createdCount');
    print('   ⏭️ Clientes existentes: $skippedCount');
    print('   📝 Total procesados: ${sampleClients.length}');
  }
  
  // Método para limpiar todos los clientes (solo para desarrollo)
  static Future<void> clearAllClients() async {
    print('🗑️ Limpiando todos los clientes...');
    
    try {
      final clients = await ClientService.getAllClients();
      int deletedCount = 0;
      
      for (final client in clients) {
        if (client.id != null) {
          await ClientService.deleteClient(client.id!);
          deletedCount++;
        }
      }
      
      print('✅ Clientes eliminados: $deletedCount');
    } catch (e) {
      print('❌ Error al limpiar clientes: $e');
    }
  }
  
  // Método para mostrar estadísticas
  static Future<void> showClientStats() async {
    try {
      final stats = await ClientService.getClientStats();
      print('📊 Estadísticas de clientes:');
      print('   📝 Total de clientes: ${stats['total_clients']}');
      print('   ✅ Clientes activos: ${stats['active_clients']}');
      print('   ❌ Clientes inactivos: ${stats['inactive_clients']}');
    } catch (e) {
      print('❌ Error al obtener estadísticas: $e');
    }
  }

  // Método para poblar la base de datos con productos de ejemplo
  static Future<void> populateSampleProducts() async {
    print('🔧 Poblando base de datos con productos de ejemplo...');
    
    int createdCount = 0;
    int skippedCount = 0;
    
    for (final productData in sampleProducts) {
      try {
        // Verificar si el producto ya existe
        final exists = await SQLiteDatabaseService.existsProductCode(productData['code']);
        if (exists) {
          print('ℹ️ Producto ya existe: ${productData['name']}');
          skippedCount++;
          continue;
        }
        
        // Crear el producto
        final product = Product(
          code: productData['code'],
          shortCode: productData['code'].length > 8 ? productData['code'].substring(0, 8) : productData['code'],
          name: productData['name'],
          description: productData['description'] ?? '',
          price: productData['price'],
          cost: productData['cost'],
          stock: productData['stock'],
          minStock: productData['minStock'],
          category: _parseCategory(productData['category']),
          unit: productData['unit'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
          isWeighted: productData['isWeighted'] ?? false,
          pricePerKg: productData['pricePerKg'],
          minWeight: productData['minWeight'],
          maxWeight: productData['maxWeight'],
        );
        
        await SQLiteDatabaseService.createProduct(product);
        print('✅ Producto creado: ${product.name}');
        createdCount++;
      } catch (e) {
        print('❌ Error al crear producto ${productData['name']}: $e');
      }
    }
    
    print('📊 Resumen de población de productos:');
    print('   ✅ Productos creados: $createdCount');
    print('   ⏭️ Productos existentes: $skippedCount');
    print('   📝 Total procesados: ${sampleProducts.length}');
  }

  // Método para limpiar todos los productos (solo para desarrollo)
  static Future<void> clearAllProducts() async {
    print('🗑️ Limpiando todos los productos...');
    
    try {
      final products = await SQLiteDatabaseService.getAllProducts();
      int deletedCount = 0;
      
      for (final product in products) {
        if (product.id != null) {
          await SQLiteDatabaseService.deleteProduct(product.id!);
          deletedCount++;
        }
      }
      
      print('✅ Productos eliminados: $deletedCount');
    } catch (e) {
      print('❌ Error al limpiar productos: $e');
    }
  }

  // Método para mostrar estadísticas de productos
  static Future<void> showProductStats() async {
    try {
      final products = await SQLiteDatabaseService.getAllProducts();
      print('📊 Estadísticas de productos:');
      print('   📝 Total de productos: ${products.length}');
      print('   ✅ Productos activos: ${products.where((p) => p.isActive).length}');
      print('   📦 Productos con stock: ${products.where((p) => p.stock > 0).length}');
      print('   ⚠️ Productos con stock bajo: ${products.where((p) => p.stock <= p.minStock).length}');
    } catch (e) {
      print('❌ Error al obtener estadísticas de productos: $e');
    }
  }

  // Función auxiliar para parsear categoría
  static ProductCategory _parseCategory(String? categoryString) {
    if (categoryString == null) return ProductCategory.otros;
    
    switch (categoryString.toLowerCase()) {
      case 'frutas y verduras':
        return ProductCategory.frutasVerduras;
      case 'lácteos':
        return ProductCategory.lacteos;
      case 'panadería':
        return ProductCategory.panaderia;
      case 'bebidas':
        return ProductCategory.bebidas;
      case 'abarrotes':
        return ProductCategory.abarrotes;
      case 'limpieza':
        return ProductCategory.limpieza;
      case 'cuidado personal':
        return ProductCategory.cuidadoPersonal;
      case 'carnes':
        return ProductCategory.carnes;
      default:
        return ProductCategory.otros;
    }
  }
} 