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
import 'screens/cash_pickups_screen.dart';
import 'screens/suppliers_screen.dart';
import 'modules/accounting/screens/accounts_receivable_payable_screen.dart';
import 'modules/accounting/screens/accounting_reports_screen.dart';


import 'modules/electronic_invoicing/screens/electronic_invoice_screen.dart';
import 'modules/electronic_invoicing/screens/system_configuration_screen.dart';
import 'modules/electronic_invoicing/screens/invoice_status_screen.dart';
import 'modules/electronic_invoicing/screens/pending_invoice_queue_screen.dart';
import 'services/sqlite_database_service.dart';
import 'middleware/auth_middleware.dart';
import 'services/auth_service.dart';
import 'services/permissions_service.dart';
import 'services/print_service.dart';
import 'services/company_config_service.dart';
import 'services/database_maintenance_service.dart';
import 'services/config_service.dart';

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

  // Inicializar configuración de empresa
  await CompanyConfigService.initializeCompanyConfig();
  
  // Mantenimiento automático de base de datos (en segundo plano)
  // Solo se ejecuta si está habilitado en configuración
  // Solo optimiza, NO borra datos
  _performAutomaticMaintenance();
  
  runApp(const MyApp());
}

// Función para mantenimiento automático periódico
// IMPORTANTE: SOLO OPTIMIZA, NUNCA BORRA DATOS
// Solo se ejecuta si el usuario lo tiene habilitado
void _performAutomaticMaintenance() async {
  try {
    // Verificar si el mantenimiento automático está habilitado
    final isEnabled = await ConfigService.isAutoMaintenanceEnabled();
    if (!isEnabled) {
      print('ℹ️ Mantenimiento automático desactivado por el usuario');
      return;
    }
    
    // Ejecutar en segundo plano sin bloquear el inicio
    Future.delayed(const Duration(seconds: 5), () async {
      final dbSize = await DatabaseMaintenanceService.getDatabaseSize();
      
      // Solo optimizar si la base de datos tiene más de 5MB
      // Esto evita optimizar bases de datos muy pequeñas innecesariamente
      if (dbSize > 5 * 1024 * 1024) { // Más de 5MB
        // IMPORTANTE: SOLO OPTIMIZA (VACUUM + ANALYZE)
        // VACUUM: Reorganiza datos, NO borra nada
        // ANALYZE: Mejora rendimiento, NO borra nada
        // NO SE EJECUTA: cleanOldSales, cleanOldInventoryMovements
        // NO SE EJECUTA: Ninguna función que borre datos
        await DatabaseMaintenanceService.optimizeDatabase();
      }
    }).catchError((e) {
      print('⚠️ Error en mantenimiento automático: $e');
    });
  } catch (e) {
    // Silenciar errores para no afectar el inicio de la app
    print('⚠️ Error al iniciar mantenimiento: $e');
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
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/recogidas-efectivo',
          page: () => const CashPickupsScreen(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/proveedores', 
          page: () => const SuppliersScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),
        GetPage(
          name: '/cuentas-cobrar-pagar', 
          page: () => const AccountsReceivablePayableScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),
        GetPage(
          name: '/reportes-contables', 
          page: () => const AccountingReportsScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),

        GetPage(
          name: '/facturacion-electronica', 
          page: () => const ElectronicInvoiceScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),
        
        // Rutas del módulo de facturación electrónica
        GetPage(
          name: '/electronic-invoicing/system-config', 
          page: () => const SystemConfigurationScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),
        GetPage(
          name: '/electronic-invoicing/status', 
          page: () => const InvoiceStatusScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),
        GetPage(
          name: '/electronic-invoicing/queue', 
          page: () => const PendingInvoiceQueueScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
        ),

      ],
    );
  }
}
