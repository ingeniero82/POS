import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/invoice_status_controller.dart';
import '../models/invoice_status.dart';

class InvoiceFiltersWidget extends StatefulWidget {
  final InvoiceStatusController controller;

  const InvoiceFiltersWidget({
    super.key,
    required this.controller,
  });

  @override
  State<InvoiceFiltersWidget> createState() => _InvoiceFiltersWidgetState();
}

class _InvoiceFiltersWidgetState extends State<InvoiceFiltersWidget> {
  InvoiceStatus? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;
  final _clientNameController = TextEditingController();
  final _documentNumberController = TextEditingController();
  bool _isRecent = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentFilters();
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _documentNumberController.dispose();
    super.dispose();
  }

  // ✅ Cargar filtros actuales
  void _loadCurrentFilters() {
    final currentFilters = widget.controller.currentFilters;
    if (currentFilters != null) {
      _selectedStatus = currentFilters.status;
      _startDate = currentFilters.startDate;
      _endDate = currentFilters.endDate;
      _clientNameController.text = currentFilters.clientName ?? '';
      _documentNumberController.text = currentFilters.documentNumber ?? '';
      _isRecent = currentFilters.isRecent ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.filter_list,
            color: Get.theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('Filtros de Facturas'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Filtro por estado
            Text(
              'Estado de la Factura',
              style: Get.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<InvoiceStatus>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Seleccionar estado',
              ),
              items: [
                const DropdownMenuItem<InvoiceStatus>(
                  value: null,
                  child: Text('Todos los estados'),
                ),
                ...InvoiceStatus.values.map((status) => DropdownMenuItem(
                      value: status,
                      child: Row(
                        children: [
                          Icon(
                            IconData(
                              int.parse(status.icon),
                              fontFamily: 'MaterialIcons',
                            ),
                            color: _getStatusColor(status),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(status.description),
                        ],
                      ),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // ✅ Filtro por fecha
            Text(
              'Rango de Fechas',
              style: Get.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: Get.theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _startDate != null
                                ? _formatDate(_startDate!)
                                : 'Fecha inicio',
                            style: TextStyle(
                              color: _startDate != null
                                  ? Get.theme.colorScheme.onSurface
                                  : Get.theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: Get.theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _endDate != null
                                ? _formatDate(_endDate!)
                                : 'Fecha fin',
                            style: TextStyle(
                              color: _endDate != null
                                  ? Get.theme.colorScheme.onSurface
                                  : Get.theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ✅ Filtro por cliente
            Text(
              'Cliente',
              style: Get.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _clientNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Nombre del cliente',
                prefixIcon: Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Filtro por número de documento
            Text(
              'Número de Documento',
              style: Get.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _documentNumberController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Número de factura',
                prefixIcon: Icon(Icons.receipt),
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Filtro por facturas recientes
            Row(
              children: [
                Checkbox(
                  value: _isRecent,
                  onChanged: (value) {
                    setState(() {
                      _isRecent = value ?? false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Solo facturas recientes (últimas 24 horas)',
                    style: Get.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _clearFilters,
          child: const Text('Limpiar'),
        ),
        ElevatedButton(
          onPressed: _applyFilters,
          child: const Text('Aplicar Filtros'),
        ),
      ],
    );
  }

  // ✅ Seleccionar fecha
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // ✅ Aplicar filtros
  void _applyFilters() {
    final filters = InvoiceFilterCriteria(
      status: _selectedStatus,
      startDate: _startDate,
      endDate: _endDate,
      clientName: _clientNameController.text.isNotEmpty
          ? _clientNameController.text
          : null,
      documentNumber: _documentNumberController.text.isNotEmpty
          ? _documentNumberController.text
          : null,
      isRecent: _isRecent,
    );

    widget.controller.applyFilters(filters);
    Navigator.of(context).pop();
  }

  // ✅ Limpiar filtros
  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _startDate = null;
      _endDate = null;
      _clientNameController.clear();
      _documentNumberController.clear();
      _isRecent = false;
    });
  }

  // ✅ Obtener color del estado
  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.pending:
        return Colors.orange;
      case InvoiceStatus.sent:
        return Colors.blue;
      case InvoiceStatus.accepted:
        return Colors.green;
      case InvoiceStatus.rejected:
        return Colors.red;
      case InvoiceStatus.cancelled:
        return Colors.grey;
    }
  }

  // ✅ Formatear fecha
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
