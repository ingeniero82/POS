import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/auth_service.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    // Verificar si el usuario está autenticado
    if (!AuthService.to.checkAuth()) {
      // Si no está autenticado, redirigir al login
      return const RouteSettings(name: '/login');
    }
    return null;
  }
}

class GuestMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    // Si el usuario ya está autenticado, redirigir al dashboard
    if (AuthService.to.checkAuth()) {
      return const RouteSettings(name: '/dashboard');
    }
    return null;
  }
} 