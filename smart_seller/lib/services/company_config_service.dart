import '../models/company_config.dart';
import 'sqlite_database_service.dart';

class CompanyConfigService {
  
  // Obtener la configuración de la empresa (siempre hay una sola configuración)
  static Future<CompanyConfig> getCompanyConfig() async {
    final configs = await SQLiteDatabaseService.getCompanyConfig();
    
    if (configs.isNotEmpty) {
      return configs.first;
    }
    
    // Si no existe configuración, crear una por defecto
    final defaultConfig = CompanyConfig(
      companyName: 'MI EMPRESA POS',
      address: 'Dirección de la empresa',
      phone: 'Teléfono de contacto',
      email: 'email@empresa.com',
      headerText: 'FACTURA DE VENTA',
      footerText: 'Gracias por su compra\nVuelva pronto',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await SQLiteDatabaseService.createOrUpdateCompanyConfig(defaultConfig);
    return defaultConfig;
  }
  
  // Actualizar la configuración de la empresa
  static Future<void> updateCompanyConfig(CompanyConfig config) async {
    final updatedConfig = config.copyWith(updatedAt: DateTime.now());
    await SQLiteDatabaseService.createOrUpdateCompanyConfig(updatedConfig);
  }
  
  // Crear configuración inicial si no existe
  static Future<void> initializeCompanyConfig() async {
    final existingConfigs = await SQLiteDatabaseService.getCompanyConfig();
    
    if (existingConfigs.isEmpty) {
      final defaultConfig = CompanyConfig(
        companyName: 'MI EMPRESA POS',
        address: 'Configure su dirección',
        phone: 'Configure su teléfono',
        email: 'Configure su email',
        headerText: 'FACTURA DE VENTA',
        footerText: 'Gracias por su compra\nVuelva pronto',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await SQLiteDatabaseService.createOrUpdateCompanyConfig(defaultConfig);
    }
  }
} 