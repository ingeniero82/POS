import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/user.dart';
import '../models/permissions.dart';
import '../services/sqlite_database_service.dart';
import '../services/permissions_service.dart';

class AuthService extends GetxService {
  static AuthService get to => Get.find();
  
  // Usuario actual logueado
  final Rx<User?> _currentUser = Rx<User?>(null);
  User? get currentUser => _currentUser.value;
  
  // Estado de autenticación
  final RxBool _isAuthenticated = false.obs;
  bool get isAuthenticated => _isAuthenticated.value;
  
  // Método para hacer login
  Future<bool> login(String username, String password) async {
    try {
      final user = await SQLiteDatabaseService.findUser(username, password);
      
      if (user != null) {
        _currentUser.value = user;
        _isAuthenticated.value = true;
        return true;
      }
      return false;
    } catch (e) {
      print('Error en login: $e');
      return false;
    }
  }
  
  // Método para hacer logout
  Future<void> logout() async {
    try {
      // Limpiar datos del usuario actual
      _currentUser.value = null;
      _isAuthenticated.value = false;
      
      // Navegar a la pantalla de login
      Get.offAllNamed('/login');
      
      // Mostrar mensaje de confirmación
      Get.snackbar(
        'Sesión cerrada',
        'Has cerrado sesión correctamente',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        icon: const Icon(Icons.logout, color: Colors.white),
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      print('Error en logout: $e');
    }
  }
  
  // Verificar si el usuario está autenticado
  bool checkAuth() {
    return _isAuthenticated.value && _currentUser.value != null;
  }
  
  // Obtener información del usuario actual
  String get currentUserName => _currentUser.value?.fullName ?? 'Usuario';
  String get currentUserRole {
    if (_currentUser.value == null) return 'Usuario';
    
    switch (_currentUser.value!.role) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.manager:
        return 'Gerente';
      case UserRole.cashier:
        return 'Cajero';
    }
  }
  
  // Verificar permisos del usuario actual usando el servicio
  bool hasPermission(Permission permission) {
    if (_currentUser.value == null) return false;
    
    final permissionsService = Get.find<PermissionsService>();
    return permissionsService.hasPermission(_currentUser.value!.role, permission);
  }
  
  // Verificar si puede acceder a una sección específica usando el servicio
  bool canAccessSection(String section) {
    if (_currentUser.value == null) return false;
    
    final permissionsService = Get.find<PermissionsService>();
    return permissionsService.canAccessSection(_currentUser.value!.role, section);
  }
  
  // Obtener todos los permisos del usuario actual usando el servicio
  Set<Permission> getCurrentUserPermissions() {
    if (_currentUser.value == null) return {};
    
    final permissionsService = Get.find<PermissionsService>();
    return permissionsService.getRolePermissions(_currentUser.value!.role);
  }
  
  // Verificar permisos del usuario (método legacy para compatibilidad)
  bool hasRolePermission(UserRole requiredRole) {
    if (_currentUser.value == null) return false;
    
    // El admin tiene todos los permisos
    if (_currentUser.value!.role == UserRole.admin) return true;
    
    // El gerente tiene permisos de gerente y cajero
    if (_currentUser.value!.role == UserRole.manager) {
      return requiredRole == UserRole.manager || requiredRole == UserRole.cashier;
    }
    
    // El cajero solo tiene permisos de cajero
    return _currentUser.value!.role == requiredRole;
  }
} 