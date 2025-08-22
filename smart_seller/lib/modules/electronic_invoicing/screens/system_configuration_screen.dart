import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/system_configuration_service.dart';
import '../models/system_configuration.dart';

class SystemConfigurationScreen extends StatefulWidget {
  const SystemConfigurationScreen({super.key});

  @override
  State<SystemConfigurationScreen> createState() => _SystemConfigurationScreenState();
}

class _SystemConfigurationScreenState extends State<SystemConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores para la configuración
  final _dianResolutionNumberController = TextEditingController();
  final _dianResolutionPrefixController = TextEditingController();
  final _dianResolutionRangeController = TextEditingController();
  final _currentConsecutiveController = TextEditingController();
  final _invoicePrefixController = TextEditingController();
  final _softwareIdController = TextEditingController();
  final _softwarePinController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyNitController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyCityController = TextEditingController();
  final _companyDepartmentController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _xmlOutputPathController = TextEditingController();
  final _pdfOutputPathController = TextEditingController();
  
  // Variables de estado
  String _selectedEnvironment = 'PRUEBAS';
  DateTime _selectedResolutionDate = DateTime.now();
  bool _isLoading = false;
  bool _isConfigurationValid = false;
  List<String> _validationErrors = [];
  
  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }
  
  @override
  void dispose() {
    _dianResolutionNumberController.dispose();
    _dianResolutionPrefixController.dispose();
    _dianResolutionRangeController.dispose();
    _currentConsecutiveController.dispose();
    _invoicePrefixController.dispose();
    _softwareIdController.dispose();
    _softwarePinController.dispose();
    _companyNameController.dispose();
    _companyNitController.dispose();
    _companyAddressController.dispose();
    _companyCityController.dispose();
    _companyDepartmentController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _xmlOutputPathController.dispose();
    _pdfOutputPathController.dispose();
    super.dispose();
  }
  
  // ✅ Cargar configuración existente
  Future<void> _loadConfiguration() async {
    setState(() => _isLoading = true);
    
    try {
      final config = await SystemConfigurationService.getConfiguration();
      
      setState(() {
        _dianResolutionNumberController.text = config.dianResolutionNumber;
        _dianResolutionPrefixController.text = config.dianResolutionPrefix;
        _dianResolutionRangeController.text = config.dianResolutionRange;
        _currentConsecutiveController.text = config.currentConsecutive.toString();
        _invoicePrefixController.text = config.invoicePrefix;
        _softwareIdController.text = config.softwareId;
        _softwarePinController.text = config.softwarePin;
        _selectedEnvironment = config.environment;
        _selectedResolutionDate = config.dianResolutionDate;
        _companyNameController.text = config.companyName;
        _companyNitController.text = config.companyNit;
        _companyAddressController.text = config.companyAddress;
        _companyCityController.text = config.companyCity;
        _companyDepartmentController.text = config.companyDepartment;
        _companyPhoneController.text = config.companyPhone;
        _companyEmailController.text = config.companyEmail;
        _xmlOutputPathController.text = config.xmlOutputPath;
        _pdfOutputPathController.text = config.pdfOutputPath;
        
        _isConfigurationValid = config.isValid;
        _validationErrors = config.validationErrors;
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error cargando configuración: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  // ✅ Guardar configuración
  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final config = SystemConfiguration(
        dianResolutionNumber: _dianResolutionNumberController.text.trim(),
        dianResolutionDate: _selectedResolutionDate,
        dianResolutionPrefix: _dianResolutionPrefixController.text.trim(),
        dianResolutionRange: _dianResolutionRangeController.text.trim(),
        currentConsecutive: int.tryParse(_currentConsecutiveController.text.trim()) ?? 1,
        invoicePrefix: _invoicePrefixController.text.trim(),
        softwareId: _softwareIdController.text.trim(),
        softwarePin: _softwarePinController.text.trim(),
        environment: _selectedEnvironment,
        companyName: _companyNameController.text.trim(),
        companyNit: _companyNitController.text.trim(),
        companyAddress: _companyAddressController.text.trim(),
        companyCity: _companyCityController.text.trim(),
        companyDepartment: _companyDepartmentController.text.trim(),
        companyPhone: _companyPhoneController.text.trim(),
        companyEmail: _companyEmailController.text.trim(),
        xmlOutputPath: _xmlOutputPathController.text.trim(),
        pdfOutputPath: _pdfOutputPathController.text.trim(),
        lastUpdated: DateTime.now(),
      );
      
      final success = await SystemConfigurationService.saveConfiguration(config);
      
      if (success) {
        setState(() {
          _isConfigurationValid = config.isValid;
          _validationErrors = config.validationErrors;
        });
        
        Get.snackbar(
          'Éxito',
          'Configuración del sistema guardada correctamente',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error',
          'Error al guardar la configuración',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error inesperado: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  // ✅ Cargar configuración por defecto para pruebas
  Future<void> _loadDefaultTestConfiguration() async {
    final success = await SystemConfigurationService.loadDefaultTestConfiguration();
    
    if (success) {
      await _loadConfiguration();
      Get.snackbar(
        'Configuración Cargada',
        'Se ha cargado la configuración por defecto para pruebas',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        'Error',
        'Error al cargar la configuración por defecto',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
  
  // ✅ Seleccionar fecha de resolución
  Future<void> _selectResolutionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedResolutionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedResolutionDate = picked;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Configuración del Sistema de Facturación'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help),
            onPressed: _showHelp,
            tooltip: 'Ayuda',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Header informativo
                    _buildInfoHeader(),
                    const SizedBox(height: 24),
                    
                    // ✅ Formulario de configuración
                    _buildConfigurationForm(),
                    const SizedBox(height: 24),
                    
                    // ✅ Botones de acción
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                    
                    // ✅ Estado de la configuración
                    _buildConfigurationStatus(),
                  ],
                ),
              ),
            ),
    );
  }
  
  // ✅ Widget para header informativo
  Widget _buildInfoHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Configuración del Sistema de Facturación Electrónica',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Configure todos los parámetros necesarios para emitir facturas electrónicas',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  // ✅ Widget para formulario de configuración
  Widget _buildConfigurationForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resolución DIAN',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Número de resolución
            TextFormField(
              controller: _dianResolutionNumberController,
              decoration: const InputDecoration(
                labelText: 'Número de Resolución *',
                hintText: 'Ej: RES-001-2024',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                helperText: 'Número de la resolución DIAN que autoriza la facturación',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El número de resolución es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Fecha de resolución
            InkWell(
              onTap: _selectResolutionDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha de Resolución *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                  helperText: 'Fecha de la resolución DIAN',
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedResolutionDate.day}/${_selectedResolutionDate.month}/${_selectedResolutionDate.year}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Prefijo de resolución
            TextFormField(
              controller: _dianResolutionPrefixController,
              decoration: const InputDecoration(
                labelText: 'Prefijo de Resolución *',
                hintText: 'Ej: FV, FA, TEST',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.text_fields),
                helperText: 'Prefijo asignado por la DIAN',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El prefijo de resolución es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Rango de resolución
            TextFormField(
              controller: _dianResolutionRangeController,
              decoration: const InputDecoration(
                labelText: 'Rango de Facturas *',
                hintText: 'Ej: 1-999999',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.format_list_numbered),
                helperText: 'Rango de consecutivos permitidos por la resolución',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El rango de facturas es obligatorio';
                }
                if (!RegExp(r'^\d+-\d+$').hasMatch(value.trim())) {
                  return 'Formato: número-número (Ej: 1-999999)';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Consecutivos y Prefijos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Consecutivo actual
            TextFormField(
              controller: _currentConsecutiveController,
              decoration: const InputDecoration(
                labelText: 'Consecutivo Actual *',
                hintText: 'Ej: 1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
                helperText: 'Último consecutivo utilizado',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El consecutivo actual es obligatorio';
                }
                if (int.tryParse(value.trim()) == null) {
                  return 'Debe ser un número válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Prefijo de factura
            TextFormField(
              controller: _invoicePrefixController,
              decoration: const InputDecoration(
                labelText: 'Prefijo de Factura *',
                hintText: 'Ej: FE, FV',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt),
                helperText: 'Prefijo para las facturas electrónicas',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El prefijo de factura es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Software de Facturación',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // ID del software
            TextFormField(
              controller: _softwareIdController,
              decoration: const InputDecoration(
                labelText: 'ID del Software *',
                hintText: 'ID asignado por la DIAN',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fingerprint),
                helperText: 'Identificador único del software de facturación',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El ID del software es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // PIN del software
            TextFormField(
              controller: _softwarePinController,
              decoration: const InputDecoration(
                labelText: 'PIN del Software *',
                hintText: '5 dígitos',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                helperText: 'PIN de 5 dígitos asignado por la DIAN',
              ),
              keyboardType: TextInputType.number,
              maxLength: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El PIN del software es obligatorio';
                }
                if (value.trim().length != 5) {
                  return 'El PIN debe tener exactamente 5 dígitos';
                }
                if (!RegExp(r'^\d{5}$').hasMatch(value.trim())) {
                  return 'El PIN debe contener solo números';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Ambiente
            DropdownButtonFormField<String>(
              value: _selectedEnvironment,
              items: [
                DropdownMenuItem(
                  value: 'PRUEBAS',
                  child: Row(
                    children: [
                      Icon(Icons.science, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text('Pruebas'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'PRODUCCION',
                  child: Row(
                    children: [
                      Icon(Icons.rocket_launch, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text('Producción'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedEnvironment = value);
                }
              },
              decoration: const InputDecoration(
                labelText: 'Ambiente *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
                helperText: 'Seleccione el ambiente de trabajo',
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Datos de la Empresa (Emisor)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Nombre de la empresa
            TextFormField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la Empresa *',
                hintText: 'Razón social',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
                helperText: 'Nombre o razón social de la empresa',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre de la empresa es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // NIT de la empresa
            TextFormField(
              controller: _companyNitController,
              decoration: const InputDecoration(
                labelText: 'NIT de la Empresa *',
                hintText: 'Ej: 900123456-7',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
                helperText: 'Número de identificación tributaria',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El NIT de la empresa es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Dirección de la empresa
            TextFormField(
              controller: _companyAddressController,
              decoration: const InputDecoration(
                labelText: 'Dirección de la Empresa *',
                hintText: 'Dirección completa',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
                helperText: 'Dirección física de la empresa',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La dirección de la empresa es obligatoria';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Ciudad de la empresa
            TextFormField(
              controller: _companyCityController,
              decoration: const InputDecoration(
                labelText: 'Ciudad de la Empresa *',
                hintText: 'Ciudad',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
                helperText: 'Ciudad donde se ubica la empresa',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La ciudad de la empresa es obligatoria';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Departamento de la empresa
            TextFormField(
              controller: _companyDepartmentController,
              decoration: const InputDecoration(
                labelText: 'Departamento de la Empresa *',
                hintText: 'Departamento',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.map),
                helperText: 'Departamento donde se ubica la empresa',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El departamento de la empresa es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Teléfono de la empresa
            TextFormField(
              controller: _companyPhoneController,
              decoration: const InputDecoration(
                labelText: 'Teléfono de la Empresa *',
                hintText: 'Ej: 3001234567',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
                helperText: 'Teléfono de contacto de la empresa',
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El teléfono de la empresa es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Email de la empresa
            TextFormField(
              controller: _companyEmailController,
              decoration: const InputDecoration(
                labelText: 'Email de la Empresa *',
                hintText: 'correo@empresa.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
                helperText: 'Correo electrónico de la empresa',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El email de la empresa es obligatorio';
                }
                if (!GetUtils.isEmail(value.trim())) {
                  return 'Formato de email inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Rutas de Archivos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Ruta XML
            TextFormField(
              controller: _xmlOutputPathController,
              decoration: const InputDecoration(
                labelText: 'Ruta de Salida XML *',
                hintText: './facturas/xml',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder),
                helperText: 'Carpeta donde se guardarán los archivos XML',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La ruta de salida XML es obligatoria';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Ruta PDF
            TextFormField(
              controller: _pdfOutputPathController,
              decoration: const InputDecoration(
                labelText: 'Ruta de Salida PDF *',
                hintText: './facturas/pdf',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.picture_as_pdf),
                helperText: 'Carpeta donde se guardarán los archivos PDF',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La ruta de salida PDF es obligatoria';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // ✅ Widget para botones de acción
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _loadDefaultTestConfiguration,
            icon: const Icon(Icons.science),
            label: const Text('Cargar Configuración de Pruebas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveConfiguration,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_isLoading ? 'Guardando...' : 'Guardar Configuración'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
  
  // ✅ Widget para estado de la configuración
  Widget _buildConfigurationStatus() {
    return Card(
      color: _isConfigurationValid ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isConfigurationValid ? Icons.check_circle : Icons.error,
                  color: _isConfigurationValid ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isConfigurationValid 
                        ? '✅ Configuración Completa' 
                        : '❌ Configuración Incompleta',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isConfigurationValid ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isConfigurationValid
                  ? 'El sistema está configurado correctamente para facturación electrónica'
                  : 'Complete todos los campos obligatorios para habilitar la facturación',
              style: TextStyle(
                color: _isConfigurationValid ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            if (_validationErrors.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Campos faltantes o incorrectos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...(_validationErrors.map((error) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(error)),
                  ],
                ),
              ))),
            ],
            if (_selectedEnvironment == 'PRODUCCION') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ AMBIENTE DE PRODUCCIÓN: Las facturas emitidas serán reales y válidas fiscalmente',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // ✅ Mostrar ayuda
  void _showHelp() {
    Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help, color: Colors.blue),
            SizedBox(width: 8),
            Text('Ayuda - Configuración del Sistema'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta pantalla permite configurar todos los parámetros del sistema de facturación electrónica:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('• Resolución DIAN: Autorización oficial para facturar'),
            Text('• Consecutivos: Control de numeración de facturas'),
            Text('• Software: Identificación del software de facturación'),
            Text('• Empresa: Datos del emisor de las facturas'),
            Text('• Rutas: Ubicación de archivos XML y PDF'),
            SizedBox(height: 16),
            Text(
              '⚠️ IMPORTANTE: Solo use Producción cuando esté completamente configurado',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
