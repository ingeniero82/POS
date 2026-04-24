import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../models/sale.dart';
import '../modules/accounting/services/accounting_service.dart';
import '../screens/pos_controller.dart';
import '../services/auth_service.dart';
import '../services/sqlite_database_service.dart';

/// Devolución POS post-venta por ítems (una o varias por factura).
/// Trazabilidad: cada fila guardada lleva [SaleItem.originalItemIndex];
/// inventario, movimientos, caja, puntos y reportes siguen el mismo flujo que la devolución total.
Future<void> showPartialReturnDialog({
  required BuildContext dialogContext,
  required BuildContext detailContext,
  required Sale original,
  required NumberFormat currencyFormat,
  required VoidCallback onSuccess,
  ValueChanged<double>? onImmediateExchangeCreditCreated,
}) async {
  await showDialog<void>(
    context: dialogContext,
    barrierDismissible: false,
    builder: (ctx) => _PartialReturnDialogBody(
      detailContext: detailContext,
      original: original,
      currencyFormat: currencyFormat,
      onSuccess: onSuccess,
      onImmediateExchangeCreditCreated: onImmediateExchangeCreditCreated,
    ),
  );
}

class _PartialReturnDialogBody extends StatefulWidget {
  const _PartialReturnDialogBody({
    required this.detailContext,
    required this.original,
    required this.currencyFormat,
    required this.onSuccess,
    this.onImmediateExchangeCreditCreated,
  });

  final BuildContext detailContext;
  final Sale original;
  final NumberFormat currencyFormat;
  final VoidCallback onSuccess;
  final ValueChanged<double>? onImmediateExchangeCreditCreated;

  @override
  State<_PartialReturnDialogBody> createState() =>
      _PartialReturnDialogBodyState();
}

class _PartialReturnDialogBodyState extends State<_PartialReturnDialogBody> {
  bool _loading = true;
  String? _loadError;
  late List<bool> _useKg;
  late List<int> _maxQty;
  late List<double> _maxKg;
  late List<TextEditingController> _qtyCtrls;
  late List<TextEditingController> _kgCtrls;
  String _metodo = 'Efectivo';
  /// Si true, acredita al [Customer.storeCredit] (requiere [Sale.customerId] en la factura).
  bool _acreditarSaldoFavor = false;
  /// Si true, registra la devolución como «Cambio inmediato» para aplicarla en POS sin salida física de caja.
  bool _usarCambioInmediato = false;
  bool _submitting = false;

  Sale get _o => widget.original;

  @override
  void initState() {
    super.initState();
    _useKg = [];
    _maxQty = [];
    _maxKg = [];
    _qtyCtrls = [];
    _kgCtrls = [];
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final id = _o.id;
    if (id == null) {
      setState(() {
        _loading = false;
        _loadError = 'Factura sin ID';
      });
      return;
    }
    try {
      final agg = await SQLiteDatabaseService.getReturnedByLineIndexAggregated(
        id,
        _o,
      );
      final useKgList = <bool>[];
      final maxQ = <int>[];
      final maxK = <double>[];
      for (var i = 0; i < _o.items.length; i++) {
        final line = _o.items[i];
        final useKg =
            await SQLiteDatabaseService.saleLineUsesKgInventoryStock(line);
        useKgList.add(useKg);
        final a = agg[i] ?? (qty: 0, kg: 0.0);
        if (useKg) {
          final w = line.weightKg ?? 0.0;
          maxQ.add(0);
          maxK.add(math.max(0.0, w - a.kg));
        } else {
          maxQ.add(math.max(0, line.quantity - a.qty));
          maxK.add(0.0);
        }
      }
      if (!mounted) return;
      setState(() {
        _useKg = useKgList;
        _maxQty = maxQ;
        _maxKg = maxK;
        _qtyCtrls = List.generate(
          _o.items.length,
          (_) => TextEditingController(text: '0'),
        );
        _kgCtrls = List.generate(
          _o.items.length,
          (_) => TextEditingController(text: '0'),
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _qtyCtrls) {
      c.dispose();
    }
    for (final c in _kgCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  double _parseKg(String s) {
    final t = s.trim().replaceAll(',', '.');
    return double.tryParse(t) ?? 0.0;
  }

  int _parseQty(String s) => int.tryParse(s.trim()) ?? 0;

  Map<String, dynamic> _readSelectionsRaw() {
    final qtyMap = <int, int>{};
    final kgMap = <int, double>{};
    for (var i = 0; i < _o.items.length; i++) {
      if (_useKg[i]) {
        final v = _parseKg(_kgCtrls[i].text);
        if (v > 1e-9) kgMap[i] = v;
      } else {
        final v = _parseQty(_qtyCtrls[i].text);
        if (v > 0) qtyMap[i] = v;
      }
    }
    return {'qty': qtyMap, 'kg': kgMap};
  }

  double _previewAmount(Map<int, int> q, Map<int, double> k) {
    final raw = SQLiteDatabaseService.computePartialReturnCustomerAmount(
      _o,
      q,
      k,
    );
    return raw;
  }

  Future<void> _markAllPending() async {
    final id = _o.id;
    if (id == null) return;
    final agg = await SQLiteDatabaseService.getReturnedByLineIndexAggregated(
      id,
      _o,
    );
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _o.items.length; i++) {
        final a = agg[i] ?? (qty: 0, kg: 0.0);
        final line = _o.items[i];
        if (_useKg[i]) {
          final w = line.weightKg ?? 0.0;
          final rem = math.max(0.0, w - a.kg);
          _maxKg[i] = rem;
          _kgCtrls[i].text = rem > 1e-9 ? rem.toStringAsFixed(3) : '0';
        } else {
          final rem = math.max(0, line.quantity - a.qty);
          _maxQty[i] = rem;
          _qtyCtrls[i].text = rem > 0 ? rem.toString() : '0';
        }
      }
    });
  }

  Future<void> _submit() async {
    final id = _o.id;
    if (id == null) return;

    final sel = _readSelectionsRaw();
    final qtyMap = sel['qty'] as Map<int, int>;
    final kgMap = sel['kg'] as Map<int, double>;
    if (qtyMap.isEmpty && kgMap.isEmpty) {
      Get.snackbar(
        'Cantidad',
        'Indique al menos un producto o peso a devolver.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    final agg = await SQLiteDatabaseService.getReturnedByLineIndexAggregated(
      id,
      _o,
    );
    for (var i = 0; i < _o.items.length; i++) {
      final a = agg[i] ?? (qty: 0, kg: 0.0);
      if (_useKg[i]) {
        final want = kgMap[i] ?? 0.0;
        if (want <= 1e-9) continue;
        final sold = _o.items[i].weightKg ?? 0.0;
        final maxRem = math.max(0.0, sold - a.kg);
        if (want > maxRem + 1e-6) {
          Get.snackbar(
            'Validación',
            'Línea ${i + 1}: máximo devoluble ahora ${maxRem.toStringAsFixed(3)} kg.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }
      } else {
        final want = qtyMap[i] ?? 0;
        if (want <= 0) continue;
        final sold = _o.items[i].quantity;
        final maxRem = math.max(0, sold - a.qty);
        if (want > maxRem) {
          Get.snackbar(
            'Validación',
            'Línea ${i + 1}: máximo devoluble ahora $maxRem u.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }
      }
    }

    final already =
        await SQLiteDatabaseService.getTotalReturnedCashForOriginal(id);
    final remain = (_o.total - already).clamp(0.0, _o.total);
    final raw = SQLiteDatabaseService.computePartialReturnCustomerAmount(
      _o,
      qtyMap,
      kgMap,
    );
    final totalReturn = math.min(raw, remain).roundToDouble();
    if (totalReturn <= 0) {
      Get.snackbar(
        'Monto',
        'El monto a devolver es cero o la factura ya no tiene saldo devoluble.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    final discPortion =
        SQLiteDatabaseService.computePartialReturnGlobalDiscountAmount(
      _o,
      qtyMap,
      kgMap,
    );

    final returnItems = <SaleItem>[];
    for (var i = 0; i < _o.items.length; i++) {
      final origLine = _o.items[i];
      if (_useKg[i]) {
        final rK = kgMap[i] ?? 0.0;
        if (rK <= 1e-9) continue;
        final w0 = origLine.weightKg ?? 0.0;
        final frac = w0 > 1e-9 ? (rK / w0).clamp(0.0, 1.0) : 0.0;
        final d = origLine.discount;
        returnItems.add(SaleItem(
          name: origLine.name,
          price: origLine.price * frac,
          quantity: 1,
          unit: origLine.unit,
          discount: d != null ? d * frac : null,
          discountPercentage: origLine.discountPercentage,
          ivaPercentage: origLine.ivaPercentage,
          productId: origLine.productId,
          weightKg: rK,
          priceEditedInCart: origLine.priceEditedInCart,
          originalUnitPrice: origLine.originalUnitPrice,
          priceEditedAt: origLine.priceEditedAt,
          priceEditedBy: origLine.priceEditedBy,
          priceEditedFromIva: origLine.priceEditedFromIva,
          originalItemIndex: i,
        ));
      } else {
        final rQ = qtyMap[i] ?? 0;
        if (rQ <= 0) continue;
        final q0 = origLine.quantity;
        final frac = q0 > 0 ? (rQ / q0).clamp(0.0, 1.0) : 0.0;
        final d = origLine.discount;
        returnItems.add(SaleItem(
          name: origLine.name,
          price: origLine.price,
          quantity: rQ,
          unit: origLine.unit,
          discount: d != null ? d * frac : null,
          discountPercentage: origLine.discountPercentage,
          ivaPercentage: origLine.ivaPercentage,
          productId: origLine.productId,
          weightKg: null,
          priceEditedInCart: origLine.priceEditedInCart,
          originalUnitPrice: origLine.originalUnitPrice,
          priceEditedAt: origLine.priceEditedAt,
          priceEditedBy: origLine.priceEditedBy,
          priceEditedFromIva: origLine.priceEditedFromIva,
          originalItemIndex: i,
        ));
      }
    }

    if (returnItems.isEmpty) {
      Get.snackbar('Error', 'No se generaron líneas de devolución.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    setState(() => _submitting = true);
    try {
      if (await SQLiteDatabaseService.isOriginalSaleFullyReturned(_o)) {
        throw Exception('Esta factura ya está totalmente devuelta.');
      }

      if (_acreditarSaldoFavor && (_o.customerId == null || _o.customerId! <= 0)) {
        throw Exception(
            'La factura no tiene cliente del sistema; no se puede acreditar saldo a favor.');
      }

      final liquidacionMetodo = _acreditarSaldoFavor
          ? kSalePaymentMethodStoreCredit
          : (_usarCambioInmediato
              ? kSalePaymentMethodInstantExchange
              : _metodo);
      final user = AuthService.to.currentUser?.username ?? 'usuario';
      final returnSale = Sale(
        date: DateTime.now(),
        total: totalReturn,
        user: user,
        paymentMethod: liquidacionMetodo,
        items: returnItems,
        paymentBreakdown: null,
        customerId: _o.customerId,
        clientId: _o.clientId,
        discount: discPortion > 0 ? discPortion : null,
        discountPercentage: null,
        isReturn: true,
        originalSaleId: id,
        returnedAmount: totalReturn,
      );

      await SQLiteDatabaseService.saveSale(returnSale);

      try {
        final invUserId = AuthService.to.currentUser?.id ?? 1;
        await SQLiteDatabaseService.logPosReturnInventoryMovements(
          returnSale,
          invUserId,
        );
      } catch (e) {
        if (mounted) {
          Get.snackbar(
            'Movimientos inventario',
            'El stock ya se devolvió, pero no se pudo registrar el movimiento en '
                'historial: ${e.toString().replaceFirst('Exception: ', '')}',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
        }
      }

      try {
        await SQLiteDatabaseService.applyCustomerBalanceAfterReturn(
          returnSale.customerId,
          totalReturn,
        );
      } catch (e) {
        if (mounted) {
          Get.snackbar(
            'Cliente / puntos',
            'No se pudo ajustar puntos o total de compras del cliente: '
                '${e.toString().replaceFirst('Exception: ', '')}',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
        }
      }

      if (_acreditarSaldoFavor && _o.customerId != null) {
        try {
          await SQLiteDatabaseService.adjustCustomerStoreCredit(
            _o.customerId!,
            totalReturn,
          );
        } catch (e) {
          if (mounted) {
            Get.snackbar(
              'Saldo a favor',
              'Venta devuelta pero no se pudo acreditar saldo: '
                  '${e.toString().replaceFirst('Exception: ', '')}',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              duration: const Duration(seconds: 6),
            );
          }
        }
      }

      if (_usarCambioInmediato) {
        try {
          if (widget.onImmediateExchangeCreditCreated != null) {
            widget.onImmediateExchangeCreditCreated!(totalReturn);
          } else if (Get.isRegistered<PosController>()) {
            final pos = Get.find<PosController>();
            pos.assignImmediateExchangeCredit(totalReturn, sourceSaleId: id);
          }
        } catch (_) {}
      }

      final uid = AuthService.to.currentUser?.id;
      if (uid != null) {
        try {
          await AccountingService.recordExpense(
            totalReturn,
            _acreditarSaldoFavor
                ? 'Acreditación saldo a favor · Devolución mov. #${returnSale.id!.toString().padLeft(6, '0')} · Fact. orig. #${id.toString().padLeft(6, '0')}'
                : 'Devolución parcial factura #${id.toString().padLeft(6, '0')} '
                    '(mov. #${returnSale.id!.toString().padLeft(6, '0')})',
            uid,
            category: _acreditarSaldoFavor
                ? 'Devolución POS (saldo a favor)'
                : 'Devolución POS',
            paymentMethod: liquidacionMetodo,
            reference: 'return_of_${id}_${DateTime.now().millisecondsSinceEpoch}',
          );
        } catch (e) {
          if (mounted) {
            Get.snackbar(
              'Aviso contable',
              'La devolución quedó registrada en ventas/stock, pero no se pudo '
                  'registrar el asiento contable: ${e.toString().replaceFirst('Exception: ', '')}',
              backgroundColor: Colors.orange,
              colorText: Colors.white,
              duration: const Duration(seconds: 6),
            );
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      if (widget.detailContext.mounted) {
        Navigator.of(widget.detailContext).pop();
      }
      widget.onSuccess();
      if (mounted) {
        Get.snackbar(
          'Devolución registrada',
          'Mov. #${returnSale.id} · Fact. orig. #$id · '
              '${_acreditarSaldoFavor ? 'Saldo acreditado al cliente · ' : ''}'
              '${_usarCambioInmediato ? 'Disponible para cambio inmediato en POS · ' : ''}'
              'Stock, inventario y reportes.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Error',
          e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        content: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_loadError != null) {
      return AlertDialog(
        title: const Text('Error'),
        content: Text(_loadError!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      );
    }

    final sel = _readSelectionsRaw();
    final preview = _previewAmount(
      sel['qty'] as Map<int, int>,
      sel['kg'] as Map<int, double>,
    );

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.keyboard_return, color: Colors.orange, size: 28),
          SizedBox(width: 8),
          Expanded(child: Text('Devolución por ítems')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Factura #${_o.id.toString().padLeft(6, '0')} · Cobrada: ${widget.currencyFormat.format(_o.total)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                'Indique cantidades o kg a devolver. Se registra en ventas, inventario, '
                'puntos del cliente y contabilidad: reembolso en medio de pago o acreditación '
                'a «saldo a favor» (sin salida de efectivo de caja).',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _submitting ? null : _markAllPending,
                icon: const Icon(Icons.select_all, size: 20),
                label: const Text('Devolver todo lo pendiente'),
              ),
              const SizedBox(height: 8),
              ...List<Widget>.generate(_o.items.length, (i) {
                final line = _o.items[i];
                final use = _useKg[i];
                final disabled = use ? _maxKg[i] <= 1e-9 : _maxQty[i] <= 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${line.name}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        if (disabled)
                          Text(
                            'Línea ya devuelta por completo.',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          )
                        else if (use)
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _kgCtrls[i],
                                  enabled: !_submitting,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                    labelText:
                                        'Kg a devolver (máx. ${_maxKg[i].toStringAsFixed(3)})',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          )
                        else
                          TextField(
                            controller: _qtyCtrls[i],
                            enabled: !_submitting,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText:
                                  'Unidades (máx. ${_maxQty[i]})',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              if (_o.customerId != null) ...[
                Text(
                  'Liquidación al cliente',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.brown.shade800,
                  ),
                ),
                RadioListTile<bool>(
                  dense: true,
                  title: const Text('Reembolsar (efectivo / tarjeta / transferencia)'),
                  value: false,
                  groupValue: _acreditarSaldoFavor,
                  onChanged: _submitting
                      ? null
                      : (v) {
                          if (v != null) setState(() => _acreditarSaldoFavor = v);
                        },
                ),
                RadioListTile<bool>(
                  dense: true,
                  title: const Text('Acreditar saldo a favor'),
                  subtitle: const Text(
                    'No sale efectivo de caja. El cliente podrá pagar con «Saldo a favor» en el POS.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: true,
                  groupValue: _acreditarSaldoFavor,
                  onChanged: _submitting
                      ? null
                      : (v) {
                          if (v != null) {
                            setState(() {
                              _acreditarSaldoFavor = v;
                              if (_acreditarSaldoFavor) {
                                _usarCambioInmediato = false;
                              }
                            });
                          }
                        },
                ),
                CheckboxListTile(
                  value: _usarCambioInmediato,
                  dense: true,
                  title: const Text('Aplicar como cambio inmediato en POS'),
                  subtitle: const Text(
                    'No sale efectivo de caja. El valor queda para descontar en la venta actual.',
                    style: TextStyle(fontSize: 11),
                  ),
                  onChanged: _submitting
                      ? null
                      : (v) {
                          setState(() {
                            _usarCambioInmediato = v ?? false;
                            if (_usarCambioInmediato) {
                              _acreditarSaldoFavor = false;
                            }
                          });
                        },
                ),
                const SizedBox(height: 8),
              ] else ...[
                Text(
                  'Esta factura no tiene cliente del sistema: puede reembolsar por medios de pago o marcar cambio inmediato.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                CheckboxListTile(
                  value: _usarCambioInmediato,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cambio inmediato (sin salida de caja)'),
                  subtitle: const Text(
                    'Úselo cuando el cliente se lleva otro producto en la misma atención.',
                    style: TextStyle(fontSize: 11),
                  ),
                  onChanged: _submitting
                      ? null
                      : (v) {
                          setState(() => _usarCambioInmediato = v ?? false);
                        },
                ),
                const SizedBox(height: 8),
              ],
              if (!_acreditarSaldoFavor && !_usarCambioInmediato)
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(_metodo),
                  initialValue: _metodo,
                  decoration: const InputDecoration(
                    labelText: 'Método de reembolso',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                    DropdownMenuItem(
                        value: 'Transferencia', child: Text('Transferencia')),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) {
                          if (v != null) setState(() => _metodo = v);
                        },
                ),
              const SizedBox(height: 12),
              Text(
                'Monto estimado esta devolución: ${widget.currencyFormat.format(preview)} '
                '(se ajusta al saldo pendiente de la factura).',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_submitting ? 'Guardando…' : 'Registrar devolución'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
