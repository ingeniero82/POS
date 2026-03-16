import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/inventory_movement.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../services/sqlite_database_service.dart';

String _labelTipo(MovementType t) {
  switch (t) {
    case MovementType.entrada:
      return 'Entrada';
    case MovementType.salida:
      return 'Salida';
    case MovementType.ajuste:
      return 'Ajuste';
  }
}

String _labelMotivo(MovementReason r) {
  switch (r) {
    case MovementReason.compra:
      return 'Compra';
    case MovementReason.venta:
      return 'Venta';
    case MovementReason.ajusteManual:
      return 'Ajuste manual';
    case MovementReason.perdida:
      return 'Pérdida';
    case MovementReason.devolucion:
      return 'Devolución';
    case MovementReason.consumoPropio:
      return 'Consumo propio';
    case MovementReason.otro:
      return 'Otro';
  }
}

class InventoryMovementsScreen extends StatefulWidget {
  const InventoryMovementsScreen({Key? key}) : super(key: key);

  @override
  State<InventoryMovementsScreen> createState() =>
      _InventoryMovementsScreenState();
}

class _InventoryMovementsScreenState extends State<InventoryMovementsScreen> {
  List<InventoryMovement> _movements = [];
  List<Product> _products = [];
  List<User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final movements = await SQLiteDatabaseService.getAllInventoryMovements();
      final products = await SQLiteDatabaseService.getAllProducts();
      final users = await SQLiteDatabaseService.getAllUsers();
      setState(() {
        _movements = movements;
        _products = products;
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar('Error', 'No se pudo cargar el historial: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  String _productName(int id) {
    final p = _products.firstWhereOrNull((prod) => prod.id == id);
    return p?.name ?? 'Producto desconocido';
  }

  String _userName(int id) {
    final u = _users.firstWhereOrNull((user) => user.id == id);
    return u?.fullName ?? 'Usuario desconocido';
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
          'Movimientos de Inventario',
          style: TextStyle(
            color: Color(0xFF22315B),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF22315B)),
            tooltip: 'Registrar movimiento',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => _MovementFormDialog(
                  products: _products,
                ),
              ).then((_) => _loadData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.home, color: Color(0xFF22315B)),
            onPressed: () => Get.offAllNamed('/dashboard'),
            tooltip: 'Ir al Dashboard',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _movements.isEmpty
              ? const Center(child: Text('No hay movimientos registrados.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _movements.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final m = _movements[index];
                    return ListTile(
                      leading: Icon(_iconForType(m.type),
                          color: _colorForType(m.type)),
                      title: Text(_productName(m.productId)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Tipo: ${_labelTipo(m.type)} | Motivo: ${_labelMotivo(m.reason)}'),
                          Text('Cantidad: ${m.quantity}'),
                          Text('Fecha: ${m.date.toString()}'),
                          Text('Usuario: ${_userName(m.userId)}'),
                          if (m.observations != null &&
                              m.observations!.isNotEmpty)
                            Text('Obs: ${m.observations!}'),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  IconData _iconForType(MovementType type) {
    switch (type) {
      case MovementType.entrada:
        return Icons.arrow_downward;
      case MovementType.salida:
        return Icons.arrow_upward;
      case MovementType.ajuste:
        return Icons.sync_alt;
    }
  }

  Color _colorForType(MovementType type) {
    switch (type) {
      case MovementType.entrada:
        return Colors.green;
      case MovementType.salida:
        return Colors.red;
      case MovementType.ajuste:
        return Colors.orange;
    }
  }
}

// --- Diálogo para registrar movimiento ---
class _MovementFormDialog extends StatefulWidget {
  final List<Product> products;
  const _MovementFormDialog({required this.products});

  @override
  State<_MovementFormDialog> createState() => _MovementFormDialogState();
}

class _MovementFormDialogState extends State<_MovementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  Product? _selectedProduct;
  MovementType _selectedType = MovementType.entrada;
  MovementReason _selectedReason = MovementReason.compra;
  final _quantityController = TextEditingController();
  final _obsController = TextEditingController();

  Future<void> _openProductSearch() async {
    final picked = await showDialog<Product>(
      context: context,
      builder: (ctx) => _ProductSearchDialog(products: widget.products),
    );
    if (picked != null && mounted) setState(() => _selectedProduct = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Registrar movimiento',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              InkWell(
                onTap: _openProductSearch,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Producto',
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.search, color: Colors.blue),
                    errorText: null,
                  ),
                  child: Text(
                    _selectedProduct != null
                        ? '${_selectedProduct!.name} (${_selectedProduct!.code})'
                        : 'Toca para buscar producto por nombre o código...',
                    style: TextStyle(
                      color: _selectedProduct != null
                          ? Colors.black87
                          : Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (_selectedProduct != null)
                Text(
                  'Stock actual: ${_selectedProduct!.stock} ${_selectedProduct!.unit}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MovementType>(
                initialValue: _selectedType,
                items: MovementType.values
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(_labelTipo(t))))
                    .toList(),
                onChanged: (t) => setState(() => _selectedType = t!),
                decoration: const InputDecoration(
                    labelText: 'Tipo de movimiento',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MovementReason>(
                initialValue: _selectedReason,
                items: MovementReason.values
                    .map((r) => DropdownMenuItem(
                        value: r, child: Text(_labelMotivo(r))))
                    .toList(),
                onChanged: (r) => setState(() => _selectedReason = r!),
                decoration: const InputDecoration(
                    labelText: 'Motivo', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                    labelText: 'Cantidad', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Ingresa la cantidad';
                  if (int.tryParse(v) == null) return 'Cantidad inválida';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _obsController,
                decoration: const InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (_selectedProduct == null) {
                        Get.snackbar(
                          'Producto requerido',
                          'Toca el campo Producto y busca uno para seleccionarlo.',
                          backgroundColor: Colors.orange,
                          colorText: Colors.white,
                        );
                        return;
                      }
                      if (_formKey.currentState!.validate()) {
                        try {
                          final movement = InventoryMovement(
                            productId: _selectedProduct!.id!,
                            type: _selectedType,
                            quantity: int.parse(_quantityController.text),
                            reason: _selectedReason,
                            date: DateTime.now(),
                            userId: 1, // TODO: Obtener ID del usuario actual
                            observations: _obsController.text.trim().isEmpty
                                ? null
                                : _obsController.text.trim(),
                          );

                          await SQLiteDatabaseService.saveInventoryMovement(
                              movement);

                          Get.snackbar(
                              'Éxito', 'Movimiento registrado correctamente',
                              backgroundColor: Colors.green,
                              colorText: Colors.white);
                          Navigator.of(context).pop();
                        } catch (e) {
                          Get.snackbar(
                              'Error', 'No se pudo registrar el movimiento: $e',
                              backgroundColor: Colors.red,
                              colorText: Colors.white);
                        }
                      }
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Diálogo para buscar producto por nombre o código ---
class _ProductSearchDialog extends StatefulWidget {
  final List<Product> products;

  const _ProductSearchDialog({required this.products});

  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts {
    if (_query.trim().isEmpty) {
      return List<Product>.from(widget.products)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    final q = _query.trim().toLowerCase();
    return widget.products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          (p.code.toLowerCase().contains(q)) ||
          (p.shortCode.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.search, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o código...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _query.isEmpty
                  ? '${widget.products.length} productos'
                  : '${filtered.length} resultado(s)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _query.isEmpty
                            ? 'Escribe para filtrar productos'
                            : 'No hay productos que coincidan con "$_query"',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                              style: TextStyle(color: Colors.blue.shade800),
                            ),
                          ),
                          title: Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Código: ${p.code} · Stock: ${p.stock} ${p.unit}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          onTap: () => Navigator.of(context).pop(p),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
