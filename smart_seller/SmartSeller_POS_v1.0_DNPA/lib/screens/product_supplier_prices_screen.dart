import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../models/product.dart';
import '../models/product_supplier_price.dart';
import '../models/supplier.dart';
import '../services/product_supplier_price_service.dart';
import '../services/sqlite_database_service.dart';
import '../services/supplier_service.dart';

/// Catálogo de precios de compra por producto y proveedor (Fase 1).
class ProductSupplierPricesScreen extends StatefulWidget {
  const ProductSupplierPricesScreen({super.key});

  @override
  State<ProductSupplierPricesScreen> createState() =>
      _ProductSupplierPricesScreenState();
}

class _ProductSupplierPricesScreenState
    extends State<ProductSupplierPricesScreen> {
  final _searchController = TextEditingController();
  final _money = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  List<ProductSupplierPriceDetail> _rows = [];
  bool _loading = true;
  List<Product> _allProducts = [];
  List<Supplier> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final products = await SQLiteDatabaseService.getAllProducts();
      final suppliers = await SupplierService.getAllSuppliers();
      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _suppliers = suppliers;
      });
      await _reloadList();
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', 'No se pudieron cargar datos: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadList() async {
    final q = _searchController.text.trim();
    final list = q.isEmpty
        ? await ProductSupplierPriceService.listAll()
        : await ProductSupplierPriceService.search(q);
    if (!mounted) return;
    setState(() => _rows = list);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(ProductSupplierPriceDetail row) async {
    final id = row.offer.id;
    if (id == null) return;
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Eliminar precio'),
        content: Text(
          '¿Quitar la relación de "${row.productName}" con ${row.supplierName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await ProductSupplierPriceService.deleteById(id);
    if (deleted) {
      Get.snackbar('Listo', 'Registro eliminado');
      await _reloadList();
    } else {
      Get.snackbar('Error', 'No se pudo eliminar');
    }
  }

  Future<void> _openEditDialog(ProductSupplierPriceDetail row) async {
    final refCtrl =
        TextEditingController(text: row.offer.supplierReference ?? '');
    final priceCtrl =
        TextEditingController(text: row.offer.purchasePrice.toStringAsFixed(0));

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Editar precio de compra'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Producto: ${row.productName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('Código: ${row.productCode}'),
              const SizedBox(height: 8),
              Text(
                'Proveedor: ${row.supplierName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Referencia del proveedor',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Precio de compra',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final p = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
              if (p == null || p < 0) {
                Get.snackbar('Error', 'Precio inválido');
                return;
              }
              Get.back(result: true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok == true && row.offer.id != null) {
      final p = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
      final updated = row.offer.copyWith(
        supplierReference:
            refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
        purchasePrice: p,
        updatedAt: DateTime.now(),
      );
      final success = await ProductSupplierPriceService.update(updated);
      refCtrl.dispose();
      priceCtrl.dispose();
      if (success) {
        Get.snackbar('Listo', 'Precio actualizado');
        await _reloadList();
      } else {
        Get.snackbar('Error', 'No se pudo guardar');
      }
    } else {
      refCtrl.dispose();
      priceCtrl.dispose();
    }
  }

  Future<void> _openAddDialog() async {
    if (_suppliers.isEmpty) {
      Get.snackbar(
        'Aviso',
        'Cree al menos un proveedor en el módulo Proveedores',
      );
      return;
    }
    if (_allProducts.isEmpty) {
      Get.snackbar('Aviso', 'No hay productos en inventario');
      return;
    }

    Supplier? pickedSupplier;
    Product? pickedProduct;
    final productFilterCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    List<Product> hits = [];
    String? savedRef;
    double? savedPrice;

    void filterHits(void Function(void Function()) setSt) {
      final q = productFilterCtrl.text.toLowerCase().trim();
      if (q.isEmpty) {
        setSt(() => hits = []);
        return;
      }
      setSt(() {
        hits = _allProducts
            .where((p) =>
                p.code.toLowerCase().contains(q) ||
                p.shortCode.toLowerCase().contains(q) ||
                p.name.toLowerCase().contains(q))
            .take(40)
            .toList();
      });
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSt) {
            return AlertDialog(
              title: const Text('Nuevo precio por proveedor'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Proveedor',
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Supplier>(
                            isExpanded: true,
                            value: pickedSupplier,
                            hint: const Text('Seleccione'),
                            items: _suppliers
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.name),
                                    ))
                                .toList(),
                            onChanged: (s) => setSt(() => pickedSupplier = s),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: productFilterCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Buscar producto (código o nombre)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => filterHits(setSt),
                      ),
                      if (pickedProduct != null) ...[
                        const SizedBox(height: 8),
                        ListTile(
                          dense: true,
                          tileColor: Colors.deepPurple.shade50,
                          title: Text(pickedProduct!.name),
                          subtitle: Text(
                            '${pickedProduct!.code} · ${pickedProduct!.shortCode}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setSt(() => pickedProduct = null),
                          ),
                        ),
                      ],
                      if (hits.isNotEmpty && pickedProduct == null)
                        SizedBox(
                          height: 180,
                          child: ListView.builder(
                            itemCount: hits.length,
                            itemBuilder: (_, i) {
                              final p = hits[i];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(p.code),
                                onTap: () => setSt(() {
                                  pickedProduct = p;
                                  hits = [];
                                  productFilterCtrl.clear();
                                }),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: refCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Referencia del proveedor (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Precio de compra',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (pickedSupplier == null || pickedProduct == null) {
                      Get.snackbar('Error', 'Seleccione proveedor y producto');
                      return;
                    }
                    final pr =
                        double.tryParse(priceCtrl.text.replaceAll(',', '.'));
                    if (pr == null || pr < 0) {
                      Get.snackbar('Error', 'Precio inválido');
                      return;
                    }
                    savedRef =
                        refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim();
                    savedPrice = pr;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    productFilterCtrl.dispose();
    refCtrl.dispose();
    priceCtrl.dispose();

    if (saved == true &&
        pickedSupplier != null &&
        pickedProduct != null &&
        savedPrice != null) {
      final pid = pickedProduct!.id;
      final sid = pickedSupplier!.id;
      if (pid == null || sid == null) {
        Get.snackbar('Error', 'Producto o proveedor sin identificador');
        return;
      }
      try {
        await ProductSupplierPriceService.upsert(
          ProductSupplierPrice(
            productId: pid,
            supplierId: sid,
            supplierReference: savedRef,
            purchasePrice: savedPrice!,
            updatedAt: DateTime.now(),
          ),
        );
        Get.snackbar('Listo', 'Precio guardado');
        await _reloadList();
      } catch (e) {
        Get.snackbar('Error', 'No se pudo guardar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Precios por proveedor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() => _loading = true);
              await _bootstrap();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Buscar por producto, código o proveedor…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _reloadList();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _reloadList(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _reloadList,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_rows.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _searchController.text.trim().isEmpty
                        ? 'No hay precios registrados.\nToque Agregar para vincular un producto con un proveedor.'
                        : 'Sin resultados para esa búsqueda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                itemCount: _rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final row = _rows[i];
                  final ref = row.offer.supplierReference;
                  return Card(
                    child: ListTile(
                      title: Text(
                        row.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${row.productCode} · ${row.supplierName}'),
                          if (ref != null && ref.isNotEmpty)
                            Text('Ref. proveedor: $ref'),
                          Text(
                            'Actualizado: ${_dateFmt.format(row.offer.updatedAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _money.format(row.offer.purchasePrice),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'e') _openEditDialog(row);
                              if (v == 'd') _confirmDelete(row);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'e',
                                child: Text('Editar'),
                              ),
                              PopupMenuItem(
                                value: 'd',
                                child: Text('Eliminar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
