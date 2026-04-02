import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'screens/check_license_screen.dart';
import 'screens/activation_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pos_screen.dart';

import 'screens/products_screen.dart';
import 'screens/users_screen.dart';
import 'screens/debug_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/company_config_screen.dart';
import 'screens/printer_config_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/suppliers_screen.dart';
import 'screens/inventory_movements_screen.dart';
import 'screens/balanza_diagnostico_screen.dart';
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

import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exception}');
      debugPrint('Stack: ${details.stack}');
    };
    await _runApp();
  }, (error, stack) {
    debugPrint('Error no capturado: $error');
    debugPrint('Stack: $stack');
  });
}

Future<void> _runApp() async {
  await SQLiteDatabaseService.initialize();
  Get.put(AuthService());
  Get.put(PermissionsService());
  runApp(const MyApp());
  // Permisos, impresora y config en segundo plano para que no bloquee la ventana.
  Future.delayed(const Duration(milliseconds: 500), () async {
    try {
      await PermissionsService.to.restoreDefaultPermissions();
    } catch (e, st) {
      debugPrint('Error permisos: $e $st');
    }
    try {
      await PrintService.instance.initialize();
    } catch (e, st) {
      debugPrint('Error impresora: $e $st');
    }
    try {
      await CompanyConfigService.initializeCompanyConfig();
    } catch (e, st) {
      debugPrint('Error config empresa: $e $st');
    }
  }).catchError((e, st) {
    debugPrint('Error en init en segundo plano: $e $st');
  });
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      initialRoute: '/check-license',
      getPages: [
        GetPage(name: '/check-license', page: () => const CheckLicenseScreen()),
        GetPage(name: '/activation', page: () => const ActivationScreen()),
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
          name: '/movimientos-inventario',
          page: () => const InventoryMovementsScreen(),
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
          name: '/configuracion-impresora',
          page: () => const PrinterConfigScreen(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/grupos',
          page: () => const GroupsScreen(),
          middlewares: [AuthMiddleware()], // Solo usuarios autenticados
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
        GetPage(
          name: '/balanza-diagnostico',
          page: () => const BalanzaDiagnosticoScreen(),
          middlewares: [AuthMiddleware()],
        ),
      ],
    );
  }
}
