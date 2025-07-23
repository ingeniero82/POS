import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/sqlite_database_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../models/permissions.dart';
import '../widgets/user_form_dialog.dart';
import '../widgets/user_edit_dialog.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<User> users = [];
  List<User> filteredUsers = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  UserRole? _selectedRoleFilter;
  bool? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers() {
    setState(() {
      filteredUsers = users.where((user) {
        // Filtro por texto de búsqueda
        final searchText = _searchController.text.toLowerCase();
        final matchesSearch = user.fullName.toLowerCase().contains(searchText) ||
                            user.username.toLowerCase().contains(searchText) ||
                            _getRoleText(user.role).toLowerCase().contains(searchText);
        
        // Filtro por rol
        final matchesRole = _selectedRoleFilter == null || 
                           user.role == _selectedRoleFilter;
        
        // Filtro por estado
        final matchesStatus = _selectedStatusFilter == null || 
                             user.isActive == _selectedStatusFilter;
        
        return matchesSearch && matchesRole && matchesStatus;
      }).toList();
    });
  }

  void _checkPermissions() {
    // Verificar si el usuario tiene permisos para ver usuarios
    if (!AuthService.to.hasPermission(Permission.viewUsers)) {
      Get.snackbar(
        'Acceso Denegado',
        'No tienes permisos para acceder a la gestión de usuarios',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
        duration: const Duration(seconds: 3),
      );
      // Redirigir al dashboard
      Get.offAllNamed('/dashboard');
    }
  }

  Future<void> _loadUsers() async {
    try {
      final usersList = await SQLiteDatabaseService.getAllUsers();
      setState(() {
        users = usersList;
        filteredUsers = usersList;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Error al cargar usuarios: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _openCreateUserDialog() async {
    // Verificar permisos para crear usuarios
    if (!AuthService.to.hasPermission(Permission.createUsers)) {
      Get.snackbar(
        'Permiso Denegado',
        'No tienes permisos para crear usuarios',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        icon: const Icon(Icons.warning, color: Colors.white),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const UserFormDialog(),
    );

    // Si se creó un usuario, recargar la lista
    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _openEditUserDialog(User user) async {
    // Verificar permisos para editar usuarios
    if (!AuthService.to.hasPermission(Permission.editUsers)) {
      Get.snackbar(
        'Permiso Denegado',
        'No tienes permisos para editar usuarios',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        icon: const Icon(Icons.warning, color: Colors.white),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => UserEditDialog(user: user),
    );

    // Si se editó un usuario, recargar la lista
    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _toggleUserStatus(User user) async {
    // Verificar permisos para activar/desactivar usuarios
    if (!AuthService.to.hasPermission(Permission.activateUsers)) {
      Get.snackbar(
        'Permiso Denegado',
        'No tienes permisos para activar/desactivar usuarios',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        icon: const Icon(Icons.warning, color: Colors.white),
      );
      return;
    }

    // Confirmar acción
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Confirmar acción'),
        content: Text(
          user.isActive 
            ? '¿Estás seguro de que quieres desactivar a ${user.fullName}?'
            : '¿Estás seguro de que quieres activar a ${user.fullName}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: user.isActive ? Colors.red : Colors.green,
            ),
            child: Text(
              user.isActive ? 'Desactivar' : 'Activar',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (user.id == null) {
        Get.snackbar(
          'Error',
          'ID de usuario no válido',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      final success = await SQLiteDatabaseService.toggleUserStatus(user.id!);
      
      if (success) {
        Get.snackbar(
          'Éxito',
          user.isActive 
            ? 'Usuario ${user.fullName} desactivado correctamente'
            : 'Usuario ${user.fullName} activado correctamente',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          icon: const Icon(Icons.check_circle, color: Colors.white),
        );
        
        // Recargar la lista
        _loadUsers();
      } else {
        Get.snackbar(
          'Error',
          user.username == 'admin' 
            ? 'No se puede desactivar al administrador principal'
            : 'No se pudo cambiar el estado del usuario',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al cambiar estado: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _deleteUser(User user) async {
    // Verificar permisos para eliminar usuarios
    if (!AuthService.to.hasPermission(Permission.deleteUsers)) {
      Get.snackbar(
        'Permiso Denegado',
        'No tienes permisos para eliminar usuarios',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        icon: const Icon(Icons.warning, color: Colors.white),
      );
      return;
    }

    // No permitir eliminar al admin
    if (user.username == 'admin') {
      Get.snackbar(
        'Error',
        'No se puede eliminar al administrador principal',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Confirmar eliminación con doble confirmación
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('¡Atención!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de que quieres eliminar a ${user.fullName}?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Esta acción NO se puede deshacer.',
              style: TextStyle(color: Colors.red),
            ),
            SizedBox(height: 8),
            Text('Se eliminará:'),
            Text('• Usuario: ${user.username}'),
            Text('• Nombre: ${user.fullName}'),
            Text('• Rol: ${_getRoleText(user.role)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (user.id == null) {
        Get.snackbar(
          'Error',
          'ID de usuario no válido',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      final success = await SQLiteDatabaseService.deleteUser(user.id!);
      
      if (success) {
        Get.snackbar(
          'Éxito',
          'Usuario ${user.fullName} eliminado correctamente',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          icon: Icon(Icons.check_circle, color: Colors.white),
        );
        
        // Recargar la lista
        _loadUsers();
      } else {
        Get.snackbar(
          'Error',
          'No se pudo eliminar el usuario',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al eliminar usuario: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.manager:
        return 'Gerente';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.cashier:
        return 'Cajero';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF22315B)),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Gestión de Usuarios',
          style: TextStyle(
            color: Color(0xFF22315B),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Color(0xFF22315B)),
            onPressed: () => Get.offAllNamed('/dashboard'),
            tooltip: 'Ir al Dashboard',
          ),
        ],
      ),
      body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF6C47FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestión de Usuarios',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Administra los usuarios del sistema y sus permisos',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _openCreateUserDialog,
                icon: const Icon(Icons.add, color: Color(0xFF6C47FF)),
                label: const Text(
                  'Nuevo Usuario',
                  style: TextStyle(
                    color: Color(0xFF6C47FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        // Filtros de búsqueda
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtros de Búsqueda',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22315B),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Campo de búsqueda
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, usuario o rol...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Filtro por rol
                  Expanded(
                    child: DropdownButtonFormField<UserRole?>(
                      value: _selectedRoleFilter,
                      decoration: InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todos los roles'),
                        ),
                        ...UserRole.values.map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(_getRoleText(role)),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedRoleFilter = value;
                        });
                        _filterUsers();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Filtro por estado
                  Expanded(
                    child: DropdownButtonFormField<bool?>(
                      value: _selectedStatusFilter,
                      decoration: InputDecoration(
                        labelText: 'Estado',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todos'),
                        ),
                        const DropdownMenuItem(
                          value: true,
                          child: Text('Activo'),
                        ),
                        const DropdownMenuItem(
                          value: false,
                          child: Text('Inactivo'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedStatusFilter = value;
                        });
                        _filterUsers();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Botón limpiar filtros
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _selectedRoleFilter = null;
                        _selectedStatusFilter = null;
                      });
                      _filterUsers();
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpiar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Lista de usuarios
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF6C47FF),
                  ),
                )
              : filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            users.isEmpty 
                              ? 'No hay usuarios registrados'
                              : 'No se encontraron usuarios con los filtros aplicados',
                        style: TextStyle(
                          fontSize: 18,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (users.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Intenta cambiar los filtros de búsqueda',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                        ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        return _UserCard(
                          user: user,
                          onEdit: () {
                            _openEditUserDialog(user);
                          },
                          onToggleStatus: () {
                            _toggleUserStatus(user);
                          },
                          onDelete: () {
                            _deleteUser(user);
                          },
                        );
                      },
                    ),
        ),
      ],
    ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
    Key? key,
  }) : super(key: key);

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.manager:
        return 'Gerente';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.cashier:
        return 'Cajero';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.manager:
        return Colors.orange;
      case UserRole.supervisor:
        return Colors.purple;
      case UserRole.cashier:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _getRoleColor(user.role).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.person,
              color: _getRoleColor(user.role),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          
          // Información del usuario
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22315B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRoleColor(user.role).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getRoleText(user.role),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getRoleColor(user.role),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: user.isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.isActive ? 'Activo' : 'Inactivo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: user.isActive ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                // Mostrar código de usuario si existe
                if (user.userCode != null && user.userCode!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.qr_code,
                        size: 16,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Código: ${user.userCode}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Botones de acción
          Row(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, color: Colors.blue),
                tooltip: 'Editar usuario',
              ),
              IconButton(
                onPressed: onToggleStatus,
                icon: Icon(
                  user.isActive ? Icons.block : Icons.check_circle,
                  color: user.isActive ? Colors.red : Colors.green,
                ),
                tooltip: user.isActive ? 'Desactivar usuario' : 'Activar usuario',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Eliminar usuario',
              ),
            ],
          ),
        ],
      ),
    );
  }
} 