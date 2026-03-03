import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Servicio de seguridad para manejo de contraseñas
/// 
/// Este servicio se encarga de:
/// - Hashear contraseñas con SHA-256
/// - Verificar contraseñas hasheadas
/// - Migrar contraseñas antiguas (retrocompatibilidad)
class SecurityService {
  
  /// Hashear una contraseña usando SHA-256
  /// 
  /// Convierte una contraseña de texto plano a hash SHA-256
  /// para almacenarla de forma segura en la base de datos.
  /// 
  /// Ejemplo:
  /// ```dart
  /// String hash = SecurityService.hashPassword("123456");
  /// // Resultado: "8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92"
  /// ```
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Verificar si una contraseña coincide con su hash
  /// 
  /// Compara una contraseña en texto plano con un hash almacenado.
  /// Devuelve true si coinciden, false si no.
  /// 
  /// Ejemplo:
  /// ```dart
  /// bool isValid = SecurityService.verifyPassword("123456", "hash_guardado");
  /// ```
  static bool verifyPassword(String plainPassword, String hashedPassword) {
    final hash = hashPassword(plainPassword);
    return hash == hashedPassword;
  }
  
  /// Determinar si una contraseña está hasheada o en texto plano
  /// 
  /// Detecta si una contraseña almacenada es un hash SHA-256 (64 caracteres hexadecimales)
  /// o si es texto plano.
  /// 
  /// Retorna true si es un hash, false si es texto plano
  static bool isHashed(String password) {
    // Los hashes SHA-256 son siempre 64 caracteres hexadecimales
    final hashRegex = RegExp(r'^[a-f0-9]{64}$');
    return hashRegex.hasMatch(password);
  }
  
  /// Migrar una contraseña a formato hasheado
  /// 
  /// Si la contraseña está en texto plano, la convierte a hash.
  /// Si ya está hasheada, la devuelve sin cambios.
  static String migratePassword(String password) {
    if (isHashed(password)) {
      // Ya está hasheada, devolver sin cambios
      return password;
    } else {
      // Está en texto plano, convertir a hash
      return hashPassword(password);
    }
  }
  
  /// Verificar contraseña con soporte de migración automática
  /// 
  /// Este método es retrocompatible:
  /// - Si el hash en la DB es válido, verifica normalmente
  /// - Si la contraseña en DB está en texto plano (sistema antiguo),
  ///   la verifica y luego la actualiza a hash automáticamente
  /// 
  /// Retorna true si la contraseña es correcta, false si no.
  static Future<bool> verifyPasswordWithMigration(
    String plainPassword,
    String storedPassword,
    Function(String) updatePasswordCallback,
  ) async {
    // Si la contraseña almacenada está hasheada
    if (isHashed(storedPassword)) {
      // Verificar normalmente
      return verifyPassword(plainPassword, storedPassword);
    } else {
      // Es texto plano (sistema antiguo)
      // Verificar si coincide
      if (plainPassword == storedPassword) {
        // Migrar a hash y actualizar en la base de datos
        final hashedPassword = hashPassword(plainPassword);
        await updatePasswordCallback(hashedPassword);
        return true;
      } else {
        return false;
      }
    }
  }
}

