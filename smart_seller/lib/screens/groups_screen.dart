import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/group.dart';
import '../services/sqlite_database_service.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<Group> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final groups = await SQLiteDatabaseService.getAllGroups();
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Error al cargar grupos: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showGroupDialog({Group? group}) {
    final isEditing = group != null;
    final nameController = TextEditingController(text: group?.name ?? '');
    final descriptionController = TextEditingController(text: group?.description ?? '');
    String selectedColor = group?.color ?? '#2196F3';
    String selectedIcon = group?.icon ?? 'category';

    final List<String> colors = [
      '#2196F3', // Azul
      '#4CAF50', // Verde
      '#FF9800', // Naranja
      '#F44336', // Rojo
      '#9C27B0', // Púrpura
      '#00BCD4', // Cyan
      '#FF5722', // Deep Orange
      '#795548', // Marrón
      '#607D8B', // Blue Grey
      '#E91E63', // Pink
    ];

    final List<Map<String, dynamic>> icons = [
      {'name': 'category', 'icon': Icons.category},
      {'name': 'inventory', 'icon': Icons.inventory},
      {'name': 'shopping_cart', 'icon': Icons.shopping_cart},
      {'name': 'store', 'icon': Icons.store},
      {'name': 'local_grocery_store', 'icon': Icons.local_grocery_store},
      {'name': 'restaurant', 'icon': Icons.restaurant},
      {'name': 'local_dining', 'icon': Icons.local_dining},
      {'name': 'cake', 'icon': Icons.cake},
      {'name': 'local_bar', 'icon': Icons.local_bar},
      {'name': 'local_cafe', 'icon': Icons.local_cafe},
      {'name': 'favorite', 'icon': Icons.favorite},
      {'name': 'star', 'icon': Icons.star},
      {'name': 'home', 'icon': Icons.home},
      {'name': 'work', 'icon': Icons.work},
      {'name': 'school', 'icon': Icons.school},
      {'name': 'sports_soccer', 'icon': Icons.sports_soccer},
      {'name': 'music_note', 'icon': Icons.music_note},
      {'name': 'movie', 'icon': Icons.movie},
      {'name': 'book', 'icon': Icons.book},
      {'name': 'computer', 'icon': Icons.computer},
    ];

    Get.dialog(
      AlertDialog(
        title: Text(isEditing ? 'Editar Grupo' : 'Nuevo Grupo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Grupo *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Color del grupo:'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: colors.map((color) {
                            return GestureDetector(
                              onTap: () {
                                selectedColor = color;
                                setState(() {});
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Color(int.parse(color.replaceAll('#', '0xFF'))),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selectedColor == color ? Colors.black : Colors.grey,
                                    width: selectedColor == color ? 3 : 1,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ícono del grupo:'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedIcon,
                          items: icons.map((iconData) => DropdownMenuItem<String>(
                            value: iconData['name'] as String,
                            child: Row(
                              children: [
                                Icon(iconData['icon'] as IconData),
                                const SizedBox(width: 8),
                                Text(iconData['name'] as String),
                              ],
                            ),
                          )).toList(),
                          onChanged: (value) {
                            selectedIcon = value!;
                            setState(() {});
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                Get.snackbar(
                  'Error',
                  'El nombre del grupo es obligatorio',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }

              try {
                final newGroup = Group(
                  id: group?.id,
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  color: selectedColor,
                  icon: selectedIcon,
                  createdAt: group?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                  isActive: true,
                );

                if (isEditing) {
                  await SQLiteDatabaseService.updateGroup(newGroup);
                  Get.snackbar(
                    'Éxito',
                    'Grupo actualizado correctamente',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                } else {
                  // Verificar si ya existe un grupo con ese nombre
                  final exists = await SQLiteDatabaseService.groupNameExists(newGroup.name);
                  if (exists) {
                    Get.snackbar(
                      'Error',
                      'Ya existe un grupo con ese nombre',
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }
                  
                  await SQLiteDatabaseService.createGroup(newGroup);
                  Get.snackbar(
                    'Éxito',
                    'Grupo creado correctamente',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                  
                  // Preguntar si desea crear otro grupo
                  Future.delayed(const Duration(milliseconds: 300), () {
                    Get.defaultDialog(
                      title: '¿Crear otro grupo?',
                      middleText: '¿Deseas crear otro grupo nuevo?',
                      textCancel: 'No',
                      textConfirm: 'Sí',
                      onCancel: () {
                        Get.back(); // Cierra el diálogo de confirmación
                        Get.back(); // Cierra el modal de creación
                      },
                      onConfirm: () {
                        Get.back(); // Cierra el diálogo de confirmación
                        // Limpiar el formulario para crear otro grupo
                        nameController.clear();
                        descriptionController.clear();
                        selectedColor = '#2196F3';
                        selectedIcon = 'category';
                        setState(() {});
                      },
                      barrierDismissible: false,
                    );
                  });
                }

                // Cerrar el modal y recargar grupos (para edición)
                Get.back();
                await _loadGroups();
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'Error al guardar grupo: $e',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: Text(isEditing ? 'Actualizar' : 'Crear'),
          ),
        ],
      ),
    );
  }

  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'category':
        return Icons.category;
      case 'inventory':
        return Icons.inventory;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'store':
        return Icons.store;
      case 'local_grocery_store':
        return Icons.local_grocery_store;
      case 'restaurant':
        return Icons.restaurant;
      case 'local_dining':
        return Icons.local_dining;
      case 'cake':
        return Icons.cake;
      case 'local_bar':
        return Icons.local_bar;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'favorite':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'music_note':
        return Icons.music_note;
      case 'movie':
        return Icons.movie;
      case 'book':
        return Icons.book;
      case 'computer':
        return Icons.computer;
      default:
        return Icons.category;
    }
  }

  void _showDeleteConfirmation(Group group) {
    Get.dialog(
      AlertDialog(
        title: const Text('Eliminar Grupo'),
        content: Text('¿Estás seguro de que quieres eliminar el grupo "${group.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SQLiteDatabaseService.deleteGroup(group.id!);
                Get.back();
                Get.snackbar(
                  'Éxito',
                  'Grupo eliminado correctamente',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
                _loadGroups();
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'Error al eliminar grupo: $e',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Grupos'),
        actions: [
          IconButton(
            onPressed: _loadGroups,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay grupos creados',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crea tu primer grupo para organizar tus productos',
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(int.parse(group.color.replaceAll('#', '0xFF'))),
                          child: Icon(
                            _getIconFromName(group.icon),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          group.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          group.description.isNotEmpty ? group.description : 'Sin descripción',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _showGroupDialog(group: group),
                              icon: const Icon(Icons.edit),
                              tooltip: 'Editar',
                            ),
                            IconButton(
                              onPressed: () => _showDeleteConfirmation(group),
                              icon: const Icon(Icons.delete),
                              tooltip: 'Eliminar',
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGroupDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Crear nuevo grupo',
      ),
    );
  }
} 