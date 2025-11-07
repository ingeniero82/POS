import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/permissions.dart';
import '../models/user.dart';

class PermissionsService extends GetxService {
  static PermissionsService get to => Get.find();
  
  // Permisos actuales en memoria
  final RxMap<UserRole, Set<Permission>> _currentPermissions = <UserRole, Set<Permission>>{}.obs;
  
  @override
  void onInit() {
    super.onInit();
    _loadPermissions();
  }
  
  Future<void> _loadPermissions() async {
    print('🔧 Cargando permisos...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final permissionsJson = prefs.getString('user_permissions');
      
      if (permissionsJson != null) {
        // Cargar permisos guardados
        final Map<String, dynamic> permissionsMap = json.decode(permissionsJson);
        final Map<UserRole, Set<Permission>> loadedPermissions = {};
        
        for (final entry in permissionsMap.entries) {
          final role = UserRole.values.firstWhere(
            (e) => e.toString() == entry.key,
            orElse: () => UserRole.cashier,
          );
          
          final permissionsList = List<String>.from(entry.value);
          final permissions = permissionsList.map((p) => 
            Permission.values.firstWhere(
              (e) => e.toString() == p,
              orElse: () => Permission.accessDashboard,
            )
          ).toSet();
          
          loadedPermissions[role] = permissions;
        }
        
        _currentPermissions.value = loadedPermissions;
        print('✅ Permisos cargados desde almacenamiento');
      } else {
        // Cargar permisos por defecto
        _loadDefaultPermissions();
        print('✅ Permisos por defecto cargados');
      }
    } catch (e) {
      print('❌ Error al cargar permisos: $e');
      _loadDefaultPermissions();
    }
  }
  
  void _loadDefaultPermissions() {
    // Cargar permisos por defecto
    _currentPermissions.value = Map.from(RolePermissions.permissions);
  }
  
  // Obtener permisos actuales
  Map<UserRole, Set<Permission>> get currentPermissions => Map.from(_currentPermissions);
  
  // Verificar si un rol tiene un permiso específico
  bool hasPermission(UserRole role, Permission permission) {
    return _currentPermissions[role]?.contains(permission) ?? false;
  }
  
  // Obtener todos los permisos de un rol
  Set<Permission> getRolePermissions(UserRole role) {
    return Set<Permission>.from(_currentPermissions[role] ?? {});
  }
  
  // Actualizar permisos de un rol específico
  void updateRolePermissions(UserRole role, Set<Permission> permissions) {
    _currentPermissions[role] = Set<Permission>.from(permissions);
  }
  
  // Guardar todos los permisos
  Future<bool> saveAllPermissions(Map<UserRole, Set<Permission>> permissions) async {
    try {
      print('💾 Guardando permisos...');
      
      // Actualizar permisos en memoria
      for (final entry in permissions.entries) {
        _currentPermissions[entry.key] = Set<Permission>.from(entry.value);
      }
      
      // Guardar en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final Map<String, List<String>> permissionsToSave = {};
      
      for (final entry in _currentPermissions.entries) {
        permissionsToSave[entry.key.toString()] = entry.value.map((p) => p.toString()).toList();
      }
      
      final permissionsJson = json.encode(permissionsToSave);
      await prefs.setString('user_permissions', permissionsJson);
      
      print('✅ Permisos guardados exitosamente');
      return true;
    } catch (e) {
      print('❌ Error al guardar permisos: $e');
      return false;
    }
  }
  
  // Restaurar permisos por defecto
  Future<void> restoreDefaultPermissions() async {
    try {
      print('🔄 Restaurando permisos por defecto...');
      
      _loadDefaultPermissions();
      
      // Guardar los permisos por defecto
      await saveAllPermissions(_currentPermissions);
      
      print('✅ Permisos restaurados a valores por defecto');
    } catch (e) {
      print('❌ Error al restaurar permisos: $e');
    }
  }
  
  // Verificar si un rol puede acceder a una sección específica
  bool canAccessSection(UserRole role, String section) {
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
} 