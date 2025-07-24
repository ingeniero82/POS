import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pos_screen.dart';

import 'screens/products_screen.dart';
import 'screens/users_screen.dart';
import 'screens/debug_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/company_config_screen.dart';
import 'screens/groups_screen.dart';

import 'modules/electronic_invoicing/screens/electronic_invoice_screen.dart';
import 'services/sqlite_database_service.dart';
import 'middleware/auth_middleware.dart';
import 'services/auth_service.dart';
import 'services/permissions_service.dart';
import 'services/print_service.dart';
import 'services/company_config_service.dart';
import 'utils/sample_weight_products.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar la base de datos SQLite
  await SQLiteDatabaseService.initialize();
  // Registrar AuthService en GetX
  Get.put(AuthService());
  Get.put(PermissionsService());
  // Restaurar permisos por defecto
  await PermissionsService.to.restoreDefaultPermissions();
  // Inicializar servicio de impresión
  await PrintService.instance.initialize();
  // Insertar productos pesados de ejemplo si no existen
  await _insertSampleWeightProductsIfNeeded();
  // Inicializar configuración de empresa
  await CompanyConfigService.initializeCompanyConfig();
  
  runApp(const MyApp());
}

Future<void> _insertSampleWeightProductsIfNeeded() async {
  try {
    //   Verificar si ya hay productos pesados
    final allProducts = await SQLiteDatabaseService.getAllProducts();
    final weightedProducts = allProducts.where((p) => p.isWeighted).toList();
    
    if (weightedProducts.isEmpty) {
      print('📦 No hay productos pesados, insertando productos de ejemplo...');
      await SampleWeightProducts.insertSampleProducts();
    } else {
      print('✅ Ya hay ${weightedProducts.length} productos pesados configurados');
    }
  } catch (e) {
    print('❌ Error verificando productos pesados: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Smart Seller',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C47FF),
          brightness: Brightness.light,
        ),
        // Configuración de Material 3
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
        ),
      ),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'CO'),
        Locale('es'),
      ],
      initialRoute: '/login',
      getPages: [
        GetPage(
          name: '/login', 
          page: () => const LoginScreen(),
          middlewares: [GuestMiddleware()], // Solo usuarios no autenticados
        ),
        GetPage(
          name: '/dashboard', 
          page: () => const DashboardScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),
        GetPage(
          name: '/pos', 
          page: () => const PosScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),

        GetPage(
          name: '/productos', 
          page: () => const ProductsScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),
        GetPage(
          name: '/usuarios', 
          page: () => const UsersScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),
        GetPage(
          name: '/debug', 
          page: () => const DebugScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),
        GetPage(
          name: '/clientes', 
          page: () => const CustomersScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),
        GetPage(
          name: '/reportes', 
          page: () => const ReportsScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),
        GetPage(
          name: '/configuracion-empresa', 
          page: () => const CompanyConfigScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),
        GetPage(
          name: '/grupos', 
          page: () => const GroupsScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),

        GetPage(
          name: '/facturacion-electronica', 
          page: () => const ElectronicInvoiceScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),
      ],
    );
  }
}
