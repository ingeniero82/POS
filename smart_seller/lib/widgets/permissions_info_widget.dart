import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/auth_service.dart';
import '../models/permissions.dart';

class PermissionsInfoWidget extends StatelessWidget {
  final bool showDetails;
  final VoidCallback? onViewDetails;

  const PermissionsInfoWidget({
    super.key,
    this.showDetails = false,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final authService = AuthService.to;
      final permissions = authService.getCurrentUserPermissions();
      
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C47FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.security,
                    color: Color(0xFF6C47FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Permisos del Usuario',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22315B),
                  ),
                ),
                const Spacer(),
                if (showDetails && onViewDetails != null)
                  TextButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Ver Detalles'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6C47FF),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Resumen de permisos
            Row(
              children: [
                Expanded(
                  child: _PermissionSummaryCard(
                    title: 'Total',
                    value: permissions.length.toString(),
                    icon: Icons.list,
                    color: const Color(0xFF6C47FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PermissionSummaryCard(
                    title: 'Gestión',
                    value: permissions
                        .where((p) => p.toString().contains('Users') || 
                                     p.toString().contains('Products') ||
                                     p.toString().contains('Clients'))
                        .length
                        .toString(),
                    icon: Icons.admin_panel_settings,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PermissionSummaryCard(
                    title: 'Operaciones',
                    value: permissions
                        .where((p) => p.toString().contains('POS') || 
                                     p.toString().contains('Sales') ||
                                     p.toString().contains('Inventory'))
                        .length
                        .toString(),
                    icon: Icons.point_of_sale,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            
            if (showDetails) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              
              // Lista detallada de permisos
              const Text(
                'Permisos Específicos:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22315B),
                ),
              ),
              const SizedBox(height: 8),
              
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: permissions.map((permission) => Chip(
                  label: Text(
                    RolePermissions.getPermissionDescription(permission),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: const Color(0xFF6C47FF).withOpacity(0.1),
                  labelStyle: const TextStyle(color: Color(0xFF6C47FF)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                )).toList(),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _PermissionSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _PermissionSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
} 