import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/permissions.dart';
import '../models/user.dart';

class AuthorizationCode {
  final String code;
  final String barcode;
  final UserRole role;
  final String name;
  final DateTime createdAt;
  final bool isActive;

  AuthorizationCode({
    required this.code,
    required this.barcode,
    required this.role,
    required this.name,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'barcode': barcode,
      'role': role.toString(),
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory AuthorizationCode.fromJson(Map<String, dynamic> json) {
    return AuthorizationCode(
      code: json['code'],
      barcode: json['barcode'],
      role: UserRole.values.firstWhere(
        (e) => e.toString() == json['role'],
        orElse: () => UserRole.cashier,
      ),
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
      isActive: json['isActive'] ?? true,
    );
  }
}

class AuthorizationCodesService {
  static const String _storageKey = 'authorization_codes';
  
  // Códigos predefinidos para administradores y gerentes
  static final List<AuthorizationCode> _defaultCodes = [
    AuthorizationCode(
      code: 'ADMIN123',
      barcode: 'ADMIN123456789',
      role: UserRole.admin,
      name: 'Administrador Principal',
      createdAt: DateTime.now(),
    ),
    AuthorizationCode(
      code: 'GERENTE456',
      barcode: 'GERENTE456789012',
      role: UserRole.manager,
      name: 'Gerente General',
      createdAt: DateTime.now(),
    ),
    AuthorizationCode(
      code: 'SUPER789',
      barcode: 'SUPER789012345',
      role: UserRole.admin,
      name: 'Supervisor',
      createdAt: DateTime.now(),
    ),
  ];

  // Generar código aleatorio
  static String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  // Generar código de barras único
  static String _generateBarcode() {
    return 'AUTH${DateTime.now().millisecondsSinceEpoch}';
  }

  // Obtener todos los códigos
  static Future<List<AuthorizationCode>> getAllCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final codesJson = prefs.getStringList(_storageKey) ?? [];
    
    if (codesJson.isEmpty) {
      // Si no hay códigos guardados, usar los predefinidos
      await _saveDefaultCodes();
      return _defaultCodes;
    }

    return codesJson
        .map((json) => AuthorizationCode.fromJson(jsonDecode(json)))
        .where((code) => code.isActive)
        .toList();
  }

  // Guardar códigos predefinidos
  static Future<void> _saveDefaultCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final codesJson = _defaultCodes
        .map((code) => jsonEncode(code.toJson()))
        .toList();
    await prefs.setStringList(_storageKey, codesJson);
  }

  // Verificar código
  static Future<AuthorizationCode?> verifyCode(String inputCode) async {
    final codes = await getAllCodes();
    return codes.firstWhere(
      (code) => code.code == inputCode || code.barcode == inputCode,
      orElse: () => throw Exception('Código no válido'),
    );
  }

  // Verificar si un rol puede autorizar una acción
  static Future<bool> canAuthorize(UserRole role, Permission permission) async {
    return RolePermissions.hasPermission(role, permission);
  }

  // Crear nuevo código de autorización
  static Future<AuthorizationCode> createCode({
    required String name,
    required UserRole role,
    String? customCode,
  }) async {
    final code = customCode ?? _generateRandomCode(8);
    final barcode = _generateBarcode();
    
    final newCode = AuthorizationCode(
      code: code,
      barcode: barcode,
      role: role,
      name: name,
      createdAt: DateTime.now(),
    );

    final codes = await getAllCodes();
    codes.add(newCode);
    
    await _saveCodes(codes);
    return newCode;
  }

  // Guardar códigos
  static Future<void> _saveCodes(List<AuthorizationCode> codes) async {
    final prefs = await SharedPreferences.getInstance();
    final codesJson = codes
        .map((code) => jsonEncode(code.toJson()))
        .toList();
    await prefs.setStringList(_storageKey, codesJson);
  }

  // Desactivar código
  static Future<void> deactivateCode(String code) async {
    final codes = await getAllCodes();
    final index = codes.indexWhere((c) => c.code == code);
    
    if (index != -1) {
      codes[index] = AuthorizationCode(
        code: codes[index].code,
        barcode: codes[index].barcode,
        role: codes[index].role,
        name: codes[index].name,
        createdAt: codes[index].createdAt,
        isActive: false,
      );
      await _saveCodes(codes);
    }
  }

  // Obtener códigos por rol
  static Future<List<AuthorizationCode>> getCodesByRole(UserRole role) async {
    final codes = await getAllCodes();
    return codes.where((code) => code.role == role).toList();
  }

  // Verificar si un código existe
  static Future<bool> codeExists(String code) async {
    final codes = await getAllCodes();
    return codes.any((c) => c.code == code || c.barcode == code);
  }

  // Obtener información del código
  static Future<AuthorizationCode?> getCodeInfo(String code) async {
    final codes = await getAllCodes();
    try {
      return codes.firstWhere((c) => c.code == code || c.barcode == code);
    } catch (e) {
      return null;
    }
  }

  // Reiniciar códigos a valores predefinidos
  static Future<void> resetToDefaults() async {
    await _saveDefaultCodes();
  }

  // Exportar códigos (para respaldo)
  static Future<String> exportCodes() async {
    final codes = await getAllCodes();
    return jsonEncode(codes.map((code) => code.toJson()).toList());
  }

  // Importar códigos (desde respaldo)
  static Future<void> importCodes(String jsonData) async {
    final List<dynamic> codesList = jsonDecode(jsonData);
    final codes = codesList
        .map((json) => AuthorizationCode.fromJson(json))
        .toList();
    await _saveCodes(codes);
  }
} 