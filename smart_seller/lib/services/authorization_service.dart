import 'package:get/get.dart';
import '../models/user.dart';
import '../models/permissions.dart';
import 'auth_service.dart';
import 'sqlite_database_service.dart';
import 'permissions_service.dart';

class AuthorizationService {
  static final AuthorizationService _instance = AuthorizationService._internal();
  factory AuthorizationService() => _instance;
  AuthorizationService._internal();

  // Tipos de autorización
  static const String PRICE_CHANGE = 'price_change';
  static const String WEIGHT_MANUAL = 'weight_manual';
  static const String DISCOUNT_APPLY = 'discount_apply';
  static const String CASH_DRAWER_OPEN = 'cash_drawer_open';

  // Claves de autorización (en producción deberían estar en base de datos)
  static const String ADMIN_CODE = 'ADMIN123';
  static const String SUPERVISOR_CODE = 'SUPER456';
  static const String MANAGER_CODE = 'MANAGER789';

  // Verificar si el usuario actual tiene permisos para una acción específica
  Future<bool> hasPermission(String action) async {
    try {
      final currentUser = AuthService.to.currentUser;
      if (currentUser == null) return false;

      switch (action) {
        case PRICE_CHANGE:
          return currentUser.role == UserRole.admin || 
                 currentUser.role == UserRole.manager ||
                 currentUser.role == UserRole.supervisor;
        
        case WEIGHT_MANUAL:
          return currentUser.role == UserRole.admin || 
                 currentUser.role == UserRole.manager ||
                 currentUser.role == UserRole.supervisor;
        
        case DISCOUNT_APPLY:
          return currentUser.role == UserRole.admin || 
                 currentUser.role == UserRole.manager ||
                 currentUser.role == UserRole.supervisor;
        
        case CASH_DRAWER_OPEN:
          // Solo supervisores, gerentes y administradores pueden abrir el cajón manualmente
          return currentUser.role == UserRole.admin || 
                 currentUser.role == UserRole.manager ||
                 currentUser.role == UserRole.supervisor;
        
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Verificar clave de autorización (incluye códigos de usuario)
  Future<bool> verifyAuthorizationCode(String code, String action) async {
    try {
      // Primero verificar si es un código de usuario
      final userWithCode = await _findUserByCode(code);
      if (userWithCode != null) {
        return await _verifyUserCodeAuthorization(userWithCode, action);
      }

      // Si no es código de usuario, verificar códigos de autorización predefinidos
      return await _verifyPredefinedCode(code, action);
    } catch (e) {
      print('Error al verificar código de autorización: $e');
      return false;
    }
  }

  // Buscar usuario por código
  Future<User?> _findUserByCode(String code) async {
    try {
      final users = await SQLiteDatabaseService.getAllUsers();
      return users.firstWhere(
        (user) => user.userCode == code && user.isActive,
        orElse: () => throw Exception('Usuario no encontrado'),
      );
    } catch (e) {
      return null;
    }
  }

  // Verificar autorización por código de usuario
  Future<bool> _verifyUserCodeAuthorization(User user, String action) async {
    try {
      // Verificar que el usuario tenga el permiso allowUserCode
      final permissionsService = PermissionsService.to;
      if (!permissionsService.hasPermission(user.role, Permission.allowUserCode)) {
        print('Usuario ${user.username} no tiene permiso allowUserCode');
        return false;
      }

      // Verificar permisos específicos según la acción
      switch (action) {
        case PRICE_CHANGE:
          return permissionsService.hasPermission(user.role, Permission.modifyPrice);
        
        case WEIGHT_MANUAL:
          return permissionsService.hasPermission(user.role, Permission.manualWeight);
        
        case DISCOUNT_APPLY:
          // Para descuentos, permitir a supervisores, gerentes y administradores
          return user.role == UserRole.admin || 
                 user.role == UserRole.manager ||
                 user.role == UserRole.supervisor;
        
        case CASH_DRAWER_OPEN:
          // Para cajón monedero, solo supervisores, gerentes y administradores
          return user.role == UserRole.admin || 
                 user.role == UserRole.manager ||
                 user.role == UserRole.supervisor;
        
        default:
          return false;
      }
    } catch (e) {
      print('Error al verificar autorización de usuario: $e');
      return false;
    }
  }

  // Verificar códigos predefinidos de autorización
  Future<bool> _verifyPredefinedCode(String code, String action) async {
    switch (code.toUpperCase()) {
      case ADMIN_CODE:
        return true; // Admin puede hacer todo
      case SUPERVISOR_CODE:
        return action != PRICE_CHANGE; // Supervisores no pueden cambiar precios
      case MANAGER_CODE:
        return action == DISCOUNT_APPLY || action == PRICE_CHANGE || action == CASH_DRAWER_OPEN;
      default:
        return false;
    }
  }

  // Verificar código de barras de autorización
  Future<bool> verifyBarcodeAuthorization(String barcode, String action) async {
    try {
      // Primero verificar si es un código de usuario
      final userWithCode = await _findUserByCode(barcode);
      if (userWithCode != null) {
        return await _verifyUserCodeAuthorization(userWithCode, action);
      }

      // Si no es código de usuario, verificar códigos de barras predefinidos
      final authorizedBarcodes = {
        'ADMIN001': [PRICE_CHANGE, WEIGHT_MANUAL, DISCOUNT_APPLY, CASH_DRAWER_OPEN],
        'SUPER001': [WEIGHT_MANUAL, DISCOUNT_APPLY, CASH_DRAWER_OPEN],
        'MANAGER001': [DISCOUNT_APPLY, PRICE_CHANGE, CASH_DRAWER_OPEN],
      };

      final allowedActions = authorizedBarcodes[barcode];
      if (allowedActions == null) return false;

      return allowedActions.contains(action);
    } catch (e) {
      print('Error al verificar código de barras: $e');
      return false;
    }
  }

  // Obtener información del autorizador (para mostrar en logs)
  Future<String> getAuthorizerInfo(String code) async {
    try {
      final userWithCode = await _findUserByCode(code);
      if (userWithCode != null) {
        return 'Usuario: ${userWithCode.fullName} (${userWithCode.username})';
      }

      // Para códigos predefinidos
      switch (code.toUpperCase()) {
        case ADMIN_CODE:
          return 'Administrador (Código Predefinido)';
        case SUPERVISOR_CODE:
          return 'Supervisor (Código Predefinido)';
        case MANAGER_CODE:
          return 'Gerente (Código Predefinido)';
        default:
          return 'Código: $code';
      }
    } catch (e) {
      return 'Código: $code';
    }
  }

  // Obtener mensaje de error según el tipo de acción
  String getErrorMessage(String action) {
    switch (action) {
      case PRICE_CHANGE:
        return 'No tienes permisos para cambiar precios. Contacta a un administrador o gerente.';
      case WEIGHT_MANUAL:
        return 'No tienes permisos para ingresar peso manual. Contacta a un supervisor.';
      case DISCOUNT_APPLY:
        return 'No tienes permisos para aplicar descuentos. Contacta a un supervisor.';
      case CASH_DRAWER_OPEN:
        return 'No tienes permisos para abrir el cajón monedero manualmente. Contacta a un supervisor.';
      default:
        return 'Acción no autorizada.';
    }
  }

  // Obtener título del modal según la acción
  String getModalTitle(String action) {
    switch (action) {
      case PRICE_CHANGE:
        return 'Autorización para Cambio de Precio';
      case WEIGHT_MANUAL:
        return 'Autorización para Peso Manual';
      case DISCOUNT_APPLY:
        return 'Autorización para Descuento';
      case CASH_DRAWER_OPEN:
        return 'Autorización para Abrir Cajón';
      default:
        return 'Autorización Requerida';
    }
  }

  // Obtener descripción del modal según la acción
  String getModalDescription(String action) {
    switch (action) {
      case PRICE_CHANGE:
        return 'Para cambiar el precio de este producto, necesitas autorización. Escanea el código de barras de un administrador/gerente o ingresa su código de usuario. El cambio será solo para esta venta.';
      case WEIGHT_MANUAL:
        return 'Para ingresar el peso manualmente, necesitas autorización. Escanea el código de barras de un supervisor o ingresa su código de usuario.';
      case DISCOUNT_APPLY:
        return 'Para aplicar un descuento, necesitas autorización. Escanea el código de barras de un supervisor o ingresa su código de usuario.';
      case CASH_DRAWER_OPEN:
        return 'Para abrir el cajón monedero manualmente, necesitas autorización de un supervisor. Esta acción quedará registrada en el sistema de auditoría.';
      default:
        return 'Esta acción requiere autorización.';
    }
  }

  // Registrar acción de autorización para auditoría
  Future<void> logAuthorization(String action, String authorizedBy, String details) async {
    try {
      final currentUser = AuthService.to.currentUser;
      final timestamp = DateTime.now();
      
      // Obtener información del autorizador
      final authorizerInfo = await getAuthorizerInfo(authorizedBy);
      
      // En un sistema real, esto se guardaría en la base de datos
      print('AUDITORÍA: $action - Autorizado por: $authorizerInfo - Usuario: ${currentUser?.fullName} - Fecha: $timestamp - Detalles: $details');
      
      // Aquí se podría guardar en la base de datos
      // await DatabaseService.logAuthorization(action, authorizerInfo, currentUser?.id, timestamp, details);
    } catch (e) {
      print('Error al registrar autorización: $e');
    }
  }
} 