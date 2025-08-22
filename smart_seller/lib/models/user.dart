// Modelo de usuario sin Isar

class User {
  int? id; // ID auto-incremental
  late String username;
  late String password;
  late String fullName;
  late UserRole role;
  late DateTime createdAt;
  bool isActive = true;
  String? userCode; // Código de usuario opcional
}

enum UserRole {
  admin,
  cashier,
  manager,
  supervisor,
  maintenance, // Nuevo rol para mantenimiento del sistema
} 