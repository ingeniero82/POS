import '../models/product.dart';
import '../services/sqlite_database_service.dart';

class SampleWeightProducts {
  // Productos pesados de ejemplo para testing
  static List<Product> getSampleWeightProducts() {
    return [
      // Frutas y Verduras
      Product(
        code: 'MANZ001',
        shortCode: 'MANZ001',
        name: 'Manzanas Rojas',
        description: 'Manzanas rojas frescas',
        price: 0.0, // Se calcula dinámicamente
        cost: 4000.0,
        stock: 999999, // Stock infinito para productos pesados
        minStock: 0,
        category: ProductCategory.frutasVerduras,
        unit: 'kg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isWeighted: true,
        pricePerKg: 6500.0, // $6,500 por kg
        minWeight: 0.1, // Mínimo 100g
        maxWeight: 5.0, // Máximo 5kg
      ),
      
      Product(
        code: 'PLAT001',
        shortCode: 'PLAT001',
        name: 'Plátanos',
        description: 'Plátanos frescos',
        price: 0.0,
        cost: 2000.0,
        stock: 999999,
        minStock: 0,
        category: ProductCategory.frutasVerduras,
        unit: 'kg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isWeighted: true,
        pricePerKg: 3500.0, // $3,500 por kg
        minWeight: 0.2,
        maxWeight: 10.0,
      ),
      
      Product(
        code: 'PAPA001',
        shortCode: 'PAPA001',
        name: 'Papas',
        description: 'Papas frescas',
        price: 0.0,
        cost: 1500.0,
        stock: 999999,
        minStock: 0,
        category: ProductCategory.frutasVerduras,
        unit: 'kg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isWeighted: true,
        pricePerKg: 2800.0, // $2,800 por kg
        minWeight: 0.5,
        maxWeight: 25.0,
      ),
      
      // Carnes
      Product(
        code: 'CRES001',
        shortCode: 'CRES001',
        name: 'Carne de Res',
        description: 'Carne de res fresca',
        price: 0.0,
        cost: 18000.0,
        stock: 999999,
        minStock: 0,
        category: ProductCategory.carnes,
        unit: 'kg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isWeighted: true,
        pricePerKg: 28000.0, // $28,000 por kg
        minWeight: 0.1,
        maxWeight: 5.0,
      ),
      
      Product(
        code: 'POLL001',
        shortCode: 'POLL001',
        name: 'Pollo',
        description: 'Pollo fresco',
        price: 0.0,
        cost: 8000.0,
        stock: 999999,
        minStock: 0,
        category: ProductCategory.carnes,
        unit: 'kg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isWeighted: true,
        pricePerKg: 12000.0, // $12,000 por kg
        minWeight: 0.2,
        maxWeight: 3.0,
      ),
      
      // Abarrotes
      Product(
        code: 'ARRO001',
        shortCode: 'ARRO001',
        name: 'Arroz',
        description: 'Arroz blanco',
        price: 0.0,
        cost: 2500.0,
        stock: 999999,
        minStock: 0,
        category: ProductCategory.abarrotes,
        unit: 'kg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isWeighted: true,
        pricePerKg: 4000.0, // $4,000 por kg
        minWeight: 0.5,
        maxWeight: 50.0,
      ),
      
      Product(
        code: 'FRIJ001',
        shortCode: 'FRIJ001',
        name: 'Frijoles',
        description: 'Frijoles rojos',
        price: 0.0,
        cost: 3000.0,
        stock: 999999,
        minStock: 0,
        category: ProductCategory.abarrotes,
        unit: 'kg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isWeighted: true,
        pricePerKg: 5500.0, // $5,500 por kg
        minWeight: 0.5,
        maxWeight: 25.0,
      ),
    ];
  }
  
  // Método para insertar productos de ejemplo en la base de datos
  static Future<void> insertSampleProducts() async {
    try {
      final products = getSampleWeightProducts();
      for (final product in products) {
        await SQLiteDatabaseService.createProduct(product);
      }
      print('✅ Productos pesados de ejemplo insertados exitosamente');
    } catch (e) {
      print('❌ Error insertando productos pesados: $e');
    }
  }
} 