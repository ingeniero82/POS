import 'user.dart';

// Definición de permisos específicos
enum Permission {
  // Gestión de usuarios
  viewUsers,
  createUsers,
  editUsers,
  deleteUsers,
  activateUsers,
  
  // Gestión de productos
  viewProducts,
  createProducts,
  editProducts,
  deleteProducts,
  
  // Punto de venta
  accessPOS,
  processSales,
  cancelSales,
  viewSalesHistory,
  modifyPrice, // Modificar precio temporal en POS
  manualWeight, // Ingresar peso manual cuando balanza no funciona
  
  // Inventario
  viewInventory,
  addInventory,
  removeInventory,
  viewMovements,
  
  // Reportes
  viewReports,
  exportReports,
  
  // Configuración
  accessSettings,
  modifySettings,
  
  // Dashboard
  accessDashboard,
  
  // Clientes
  viewClients,
  createClients,
  editClients,
  deleteClients,
  
  // Código de usuario
  allowUserCode, // Puede tener/usar código de usuario
}

// Configuración de permisos por rol
class RolePermissions {
  static final Map<UserRole, Set<Permission>> permissions = {
    UserRole.admin: {
      // Admin tiene todos los permisos
      Permission.viewUsers,
      Permission.createUsers,
      Permission.editUsers,
      Permission.deleteUsers,
      Permission.activateUsers,
      Permission.viewProducts,
      Permission.createProducts,
      Permission.editProducts,
      Permission.deleteProducts,
      Permission.accessPOS,
      Permission.processSales,
      Permission.cancelSales,
      Permission.viewSalesHistory,
      Permission.modifyPrice,
      Permission.manualWeight,
      Permission.viewInventory,
      Permission.addInventory,
      Permission.removeInventory,
      Permission.viewMovements,
      Permission.viewReports,
      Permission.exportReports,
      Permission.accessSettings,
      Permission.modifySettings,
      Permission.accessDashboard,
      Permission.viewClients,
      Permission.createClients,
      Permission.editClients,
      Permission.deleteClients,
      Permission.allowUserCode,
    },
    
    UserRole.manager: {
      // Gerente tiene permisos de gestión pero no puede eliminar usuarios
      Permission.viewUsers,
      Permission.createUsers,
      Permission.editUsers,
      Permission.activateUsers,
      Permission.viewProducts,
      Permission.createProducts,
      Permission.editProducts,
      Permission.deleteProducts,
      Permission.accessPOS,
      Permission.processSales,
      Permission.cancelSales,
      Permission.viewSalesHistory,
      Permission.modifyPrice,
      Permission.manualWeight,
      Permission.viewInventory,
      Permission.addInventory,
      Permission.removeInventory,
      Permission.viewMovements,
      Permission.viewReports,
      Permission.exportReports,
      Permission.accessSettings,
      Permission.accessDashboard,
      Permission.viewClients,
      Permission.createClients,
      Permission.editClients,
      Permission.deleteClients,
      Permission.allowUserCode,
    },
    
    UserRole.supervisor: {
      // Supervisor tiene permisos intermedios con capacidades de supervisión
      Permission.viewUsers,
      Permission.viewProducts,
      Permission.createProducts,
      Permission.editProducts,
      Permission.accessPOS,
      Permission.processSales,
      Permission.cancelSales,
      Permission.viewSalesHistory,
      Permission.modifyPrice,
      Permission.manualWeight,
      Permission.viewInventory,
      Permission.addInventory,
      Permission.removeInventory,
      Permission.viewMovements,
      Permission.viewReports,
      Permission.accessDashboard,
      Permission.viewClients,
      Permission.createClients,
      Permission.allowUserCode,
    },
    
    UserRole.cashier: {
      // Cajero tiene permisos limitados
      Permission.viewProducts,
      Permission.accessPOS,
      Permission.processSales,
      Permission.viewSalesHistory,
      Permission.viewInventory,
      Permission.viewMovements,
      Permission.accessDashboard,
      Permission.viewClients,
      // No tiene permiso de código de usuario
    },
  };
  
  // Verificar si un rol tiene un permiso específico
  static bool hasPermission(UserRole role, Permission permission) {
    return permissions[role]?.contains(permission) ?? false;
  }
  
  // Obtener todos los permisos de un rol
  static Set<Permission> getPermissions(UserRole role) {
    return permissions[role] ?? {};
  }
  
  // Verificar si un rol puede acceder a una sección específica
  static bool canAccessSection(UserRole role, String section) {
    switch (section.toLowerCase()) {
      case 'usuarios':
        return hasPermission(role, Permission.viewUsers);
      case 'productos':
        return hasPermission(role, Permission.viewProducts);
      case 'pos':
        return hasPermission(role, Permission.accessPOS);
      case 'inventario':
        return hasPermission(role, Permission.viewInventory);
      case 'reportes':
        return hasPermission(role, Permission.viewReports);
      case 'configuracion':
        return hasPermission(role, Permission.accessSettings);
      case 'clientes':
        return hasPermission(role, Permission.viewClients);
      case 'movimientos':
        return hasPermission(role, Permission.viewMovements);
      case 'ventas':
        return hasPermission(role, Permission.viewSalesHistory);
      default:
        return false;
    }
  }
  
  // Obtener descripción de permisos para mostrar al usuario
  static String getPermissionDescription(Permission permission) {
    switch (permission) {
      case Permission.viewUsers:
        return 'Ver usuarios';
      case Permission.createUsers:
        return 'Crear usuarios';
      case Permission.editUsers:
        return 'Editar usuarios';
      case Permission.deleteUsers:
        return 'Eliminar usuarios';
      case Permission.activateUsers:
        return 'Activar/Desactivar usuarios';
      case Permission.viewProducts:
        return 'Ver productos';
      case Permission.createProducts:
        return 'Crear productos';
      case Permission.editProducts:
        return 'Editar productos';
      case Permission.deleteProducts:
        return 'Eliminar productos';
      case Permission.accessPOS:
        return 'Acceder al punto de venta';
      case Permission.processSales:
        return 'Procesar ventas';
      case Permission.cancelSales:
        return 'Cancelar ventas';
      case Permission.viewSalesHistory:
        return 'Ver historial de ventas';
      case Permission.modifyPrice:
        return 'Modificar precio temporal en POS';
      case Permission.manualWeight:
        return 'Ingresar peso manual (balanza no funciona)';
      case Permission.viewInventory:
        return 'Ver inventario';
      case Permission.addInventory:
        return 'Agregar al inventario';
      case Permission.removeInventory:
        return 'Remover del inventario';
      case Permission.viewMovements:
        return 'Ver movimientos';
      case Permission.viewReports:
        return 'Ver reportes';
      case Permission.exportReports:
        return 'Exportar reportes';
      case Permission.accessSettings:
        return 'Acceder a configuración';
      case Permission.modifySettings:
        return 'Modificar configuración';
      case Permission.accessDashboard:
        return 'Acceder al dashboard';
      case Permission.viewClients:
        return 'Ver clientes';
      case Permission.createClients:
        return 'Crear clientes';
      case Permission.editClients:
        return 'Editar clientes';
      case Permission.deleteClients:
        return 'Eliminar clientes';
      case Permission.allowUserCode:
        return 'Puede tener/usar código de usuario';
    }
  }
} 