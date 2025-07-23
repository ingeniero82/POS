import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dashboard_controller.dart';
import 'pos_screen.dart';
import 'users_screen.dart';
import 'products_screen.dart';
import '../services/auth_service.dart';
import '../models/permissions.dart';
import '../models/user.dart';
import 'package:intl/intl.dart';
import 'customers_screen.dart';
import 'reports_screen.dart';
import 'permissions_screen.dart'; // ✅ AÑADIDO

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DashboardController());
    final authService = Get.put(AuthService());
    
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA), // Fondo general gris claro
      body: Row(
        children: [
          // Sidebar lateral
          Container(
            width: 240,
            height: double.infinity,
            color: const Color(0xFF6C47FF), // Morado original del mockup
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Solo el texto, sin logo
                const Text(
                  'smart seller',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 40),
                // Menú lateral
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    children: [
                      _SidebarButton(
                        icon: Icons.dashboard,
                        label: 'Dashboard',
                        selected: controller.selectedMenu.value == DashboardMenu.dashboard,
                        onTap: () => controller.selectMenu(DashboardMenu.dashboard),
                      ),
                      // Punto de Venta - Solo si tiene permisos
                      if (authService.hasPermission(Permission.accessPOS))
                        _SidebarButton(
                          icon: Icons.point_of_sale,
                          label: 'Punto de Venta',
                          selected: controller.selectedMenu.value == DashboardMenu.puntoDeVenta,
                          onTap: () {
                            Get.toNamed('/pos');
                          },
                        ),
                      // Inventario - Solo si tiene permisos
                      if (authService.hasPermission(Permission.viewInventory))
                        _SidebarButton(
                          icon: Icons.inventory_2,
                          label: 'Inventario',
                          selected: controller.selectedMenu.value == DashboardMenu.inventario,
                          onTap: () => controller.selectMenu(DashboardMenu.inventario),
                        ),

                      // Clientes - Solo si tiene permisos
                      if (authService.hasPermission(Permission.viewClients))
                        _SidebarButton(
                          icon: Icons.people,
                          label: 'Clientes',
                          selected: controller.selectedMenu.value == DashboardMenu.clientes,
                          onTap: () {
                            Get.toNamed('/clientes');
                          },
                        ),
                      // Reportes - Solo si tiene permisos
                      if (authService.hasPermission(Permission.viewReports))
                        _SidebarButton(
                          icon: Icons.bar_chart,
                          label: 'Reportes',
                          selected: controller.selectedMenu.value == DashboardMenu.reportes,
                          onTap: () {
                            Get.toNamed('/reportes');
                          },
                        ),
                      // Configuración - Solo si tiene permisos
                      if (authService.hasPermission(Permission.accessSettings))
                        _SidebarButton(
                          icon: Icons.settings,
                          label: 'Configuración',
                          selected: controller.selectedMenu.value == DashboardMenu.configuracion,
                          onTap: () => controller.selectMenu(DashboardMenu.configuracion),
                        ),
                      // Configuración de Empresa - Solo si tiene permisos de configuración
                      if (authService.hasPermission(Permission.accessSettings))
                        _SidebarButton(
                          icon: Icons.business,
                          label: 'Datos de Empresa',
                          selected: false,
                          onTap: () {
                            Get.toNamed('/configuracion-empresa');
                          },
                        ),
                      // Usuarios - Solo si tiene permisos
                      if (authService.hasPermission(Permission.viewUsers))
                        _SidebarButton(
                          icon: Icons.person,
                          label: 'Usuarios',
                          selected: controller.selectedMenu.value == DashboardMenu.usuarios,
                          onTap: () => controller.selectMenu(DashboardMenu.usuarios),
                        ),
                      // Permisos - Solo si tiene permisos de configuración
                      if (authService.hasPermission(Permission.modifySettings))
                        _SidebarButton(
                          icon: Icons.security,
                          label: 'Permisos',
                          selected: controller.selectedMenu.value == DashboardMenu.permisos,
                          onTap: () => controller.selectMenu(DashboardMenu.permisos),
                        ),

                    ],
                  ),
                ),
                // Sección de usuario con información dinámica y botón de logout
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(Icons.person, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Obx(() => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authService.currentUserName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    authService.currentUserRole,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Botón de logout
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showLogoutDialog(),
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Cerrar Sesión'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Contenido principal
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(32),
              color: const Color(0xFFF6F8FA), // Fondo igual al general
              child: Obx(() {
                switch (controller.selectedMenu.value) {
                  case DashboardMenu.dashboard:
                    return _DashboardContent();
                  case DashboardMenu.puntoDeVenta:
                    return const PosScreen();
                  case DashboardMenu.inventario:
                    return const ProductsScreen();
                  case DashboardMenu.clientes:
                    return const CustomersScreen();
                  case DashboardMenu.reportes:
                    return const ReportsScreen();
                  case DashboardMenu.configuracion:
                    return Center(child: Text('Configuración', style: TextStyle(fontSize: 28, color: Colors.grey[700])));
                  case DashboardMenu.usuarios:
                    return const UsersScreen();
                  case DashboardMenu.permisos:
                    return const PermissionsScreen(); // ✅ AÑADIDO
                }
              }),
            ),
          ),
        ],
      ),
    );
  }

  // Diálogo de confirmación para logout
  void _showLogoutDialog() {
    Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Cerrar Sesión'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que quieres cerrar sesión?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              AuthService.to.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
}

// Widget para los botones del sidebar
class _SidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarButton({
    required this.icon,
    required this.label,
    this.selected = false,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Material(
        color: selected ? Colors.white.withOpacity(0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget para las tarjetas de resumen
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color borderColor;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.borderColor,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7B809A),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF22315B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget para las tarjetas de acción rápida
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22315B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7B809A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Mueve todo el contenido principal del dashboard aquí
class _DashboardContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();
    
    // Funciones para los accesos rápidos
    void _nuevaVenta() {
      if (authService.hasPermission(Permission.accessPOS)) {
        Get.toNamed('/pos');
      } else {
        Get.snackbar(
          'Acceso Denegado',
          'No tienes permisos para acceder al punto de venta',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
    
    void _gestionarInventario() {
      if (authService.hasPermission(Permission.viewInventory)) {
        Get.toNamed('/productos');
      } else {
        Get.snackbar(
          'Acceso Denegado',
          'No tienes permisos para gestionar inventario',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
    
    void _gestionarClientes() {
      if (authService.hasPermission(Permission.viewClients)) {
        Get.snackbar(
          'Módulo en Desarrollo',
          'La gestión de clientes estará disponible próximamente',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Acceso Denegado',
          'No tienes permisos para gestionar clientes',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
    
    void _verReportes() {
      if (authService.hasPermission(Permission.viewReports)) {
        Get.snackbar(
          'Módulo en Desarrollo',
          'Los reportes estarán disponibles próximamente',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Acceso Denegado',
          'No tienes permisos para ver reportes',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
    
    void _configuracion() {
      if (authService.hasPermission(Permission.accessSettings)) {
        Get.toNamed('/migracion');
      } else {
        Get.snackbar(
          'Acceso Denegado',
          'No tienes permisos para acceder a configuración',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
    
    void _debug() {
      Get.toNamed('/debug');
    }
    
    void _moduleMigration() {
      Get.toNamed('/module-migration');
    }
    
    void _gestionarUsuarios() {
      if (authService.hasPermission(Permission.viewUsers)) {
        Get.toNamed('/usuarios');
      } else {
        Get.snackbar(
          'Acceso Denegado',
          'No tienes permisos para gestionar usuarios',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
        }
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Header azul
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3), // Azul principal
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Text(
                'Panel de Control',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Bienvenido de vuelta, gestiona tu supermercado de manera eficiente',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Tarjetas de resumen adaptables según permisos
        if (authService.hasPermission(Permission.viewReports)) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'VENTAS HOY',
                value: NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0, customPattern: '\u00A4#,##0').format(2450),
                subtitle: '+15% vs ayer',
                icon: Icons.monetization_on,
                color: Color(0xFF4CAF50),
                borderColor: Color(0xFF4CAF50),
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: _SummaryCard(
                title: 'PRODUCTOS VENDIDOS',
                value: '156',
                subtitle: '+8% vs ayer',
                icon: Icons.inventory_2,
                color: Color(0xFFFF9800),
                borderColor: Color(0xFFFF9800),
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: _SummaryCard(
                title: 'CLIENTES ATENDIDOS',
                value: '42',
                subtitle: '+22% vs ayer',
                icon: Icons.people,
                color: Color(0xFFF44336),
                borderColor: Color(0xFFF44336),
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: _SummaryCard(
                title: 'INGRESOS SEMANALES',
                value: NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0, customPattern: '\u00A4#,##0').format(12850),
                subtitle: '+5% vs sem. anterior',
                icon: Icons.sticky_note_2,
                color: Color(0xFF7C4DFF),
                borderColor: Color(0xFF7C4DFF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        ],
        // Mensaje para usuarios sin permisos de reportes
        if (!authService.hasPermission(Permission.viewReports)) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[700],
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'Bienvenido al Panel de Control',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Usa las acciones rápidas para acceder a las funciones disponibles.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
        // Acciones Rápidas
        const Text(
          'Acciones Rápidas',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF22315B),
          ),
        ),
        const SizedBox(height: 18),
        // Verificar si hay acciones rápidas disponibles
        Builder(
          builder: (context) {
            final hasAnyPermission = authService.hasPermission(Permission.accessPOS) ||
                                   authService.hasPermission(Permission.viewInventory) ||
                                   authService.hasPermission(Permission.viewClients) ||
                                   authService.hasPermission(Permission.viewReports) ||
                                   authService.hasPermission(Permission.accessSettings) ||
                                   authService.hasPermission(Permission.viewUsers);
            
            if (!hasAnyPermission) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: Colors.orange[700],
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sin Acciones Disponibles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No tienes permisos para acceder a ninguna función del sistema. Contacta al administrador.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            
            return Center(
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
                  // Nueva Venta - Solo si tiene permisos de POS
                  if (authService.hasPermission(Permission.accessPOS))
              _QuickActionCard(
                icon: Icons.point_of_sale,
                color: Color(0xFF2979FF),
                title: 'Nueva Venta',
                description: 'Iniciar una nueva transacción de venta y procesar productos',
                      onTap: _nuevaVenta,
              ),
                  // Gestionar Inventario - Solo si tiene permisos de inventario
                  if (authService.hasPermission(Permission.viewInventory))
              _QuickActionCard(
                icon: Icons.inventory,
                color: Color(0xFF7C4DFF),
                title: 'Gestionar Inventario',
                description: 'Administrar stock, agregar productos y controlar existencias',
                      onTap: _gestionarInventario,
              ),
                  // Gestión de Clientes - Solo si tiene permisos de clientes
                  if (authService.hasPermission(Permission.viewClients))
              _QuickActionCard(
                icon: Icons.groups,
                color: Color(0xFFFFA000),
                title: 'Gestión de Clientes',
                description: 'Registrar clientes, consultar historial y programas de fidelización',
                      onTap: _gestionarClientes,
              ),
                  // Ver Reportes - Solo si tiene permisos de reportes
                  if (authService.hasPermission(Permission.viewReports))
              _QuickActionCard(
                icon: Icons.bar_chart,
                color: Color(0xFF00BFA5),
                title: 'Ver Reportes',
                description: 'Consultar reportes de ventas, estadísticas y análisis del negocio',
                      onTap: _verReportes,
              ),
                  // Configuración - Solo si tiene permisos de configuración
                  if (authService.hasPermission(Permission.accessSettings))
              _QuickActionCard(
                icon: Icons.settings,
                color: Color(0xFF616161),
                title: 'Configuración',
                description: 'Ajustar parámetros del sistema, impuestos y configuraciones generales',
                      onTap: _configuracion,
              ),
                  // Gestión de Usuarios - Solo si tiene permisos de usuarios
                  if (authService.hasPermission(Permission.viewUsers))
              _QuickActionCard(
                icon: Icons.person,
                color: Color(0xFFD32F2F),
                title: 'Gestión de Usuarios',
                description: 'Administrar usuarios del sistema, permisos y roles de acceso',
                      onTap: _gestionarUsuarios,
              ),
            ],
          ),
            );
          },
        ),
      ],
      ),
    );
  }
} 