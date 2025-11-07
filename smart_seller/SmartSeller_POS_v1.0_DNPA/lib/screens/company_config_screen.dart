import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/company_config.dart';
import '../services/company_config_service.dart';
import '../services/permissions_service.dart';
import '../services/auth_service.dart';
import '../models/permissions.dart';
import '../models/user.dart';

class CompanyConfigScreen extends StatefulWidget {
  const CompanyConfigScreen({super.key});

  @override
  State<CompanyConfigScreen> createState() => _CompanyConfigScreenState();
}

class _CompanyConfigScreenState extends State<CompanyConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _headerTextController = TextEditingController();
  final _footerTextController = TextEditingController();
  
  // ✅ NUEVOS CONTROLADORES PARA FACTURACIÓN ELECTRÓNICA
  final _documentTypeController = TextEditingController();
  final _nitNumberController = TextEditingController();
  final _verificationDigitController = TextEditingController();
  final _cityController = TextEditingController();
  final _departmentController = TextEditingController();
  final _countryController = TextEditingController();
  final _fiscalRegimeController = TextEditingController();
  final _fiscalResponsibilitiesController = TextEditingController();
  
  bool _isLoading = true;
  CompanyConfig? _currentConfig;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    try {
      final config = await CompanyConfigService.getCompanyConfig();
      setState(() {
        _currentConfig = config;
        _companyNameController.text = config.companyName;
        _addressController.text = config.address;
        _phoneController.text = config.phone;
        _emailController.text = config.email ?? '';
        _websiteController.text = config.website ?? '';
        _taxIdController.text = config.taxId ?? '';
        _headerTextController.text = config.headerText;
        _footerTextController.text = config.footerText;
        
        // ✅ CARGAR NUEVOS CAMPOS DE FACTURACIÓN ELECTRÓNICA
        _documentTypeController.text = config.documentType ?? '31'; // Por defecto NIT
        _nitNumberController.text = config.nitNumber ?? '';
        _verificationDigitController.text = config.verificationDigit ?? '';
        _cityController.text = config.city ?? '';
        _departmentController.text = config.department ?? '';
        _countryController.text = config.country ?? 'CO'; // Por defecto Colombia
        _fiscalRegimeController.text = config.fiscalRegime ?? '';
        _fiscalResponsibilitiesController.text = config.fiscalResponsibilities ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'Error cargando configuración: $e');
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final updatedConfig = CompanyConfig(
        id: _currentConfig?.id,
        companyName: _companyNameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        taxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
        headerText: _headerTextController.text.trim(),
        footerText: _footerTextController.text.trim(),
        // ✅ NUEVOS CAMPOS DE FACTURACIÓN ELECTRÓNICA
        documentType: _documentTypeController.text.trim().isEmpty ? null : _documentTypeController.text.trim(),
        nitNumber: _nitNumberController.text.trim().isEmpty ? null : _nitNumberController.text.trim(),
        verificationDigit: _verificationDigitController.text.trim().isEmpty ? null : _verificationDigitController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        department: _departmentController.text.trim().isEmpty ? null : _departmentController.text.trim(),
        country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
        fiscalRegime: _fiscalRegimeController.text.trim().isEmpty ? null : _fiscalRegimeController.text.trim(),
        fiscalResponsibilities: _fiscalResponsibilitiesController.text.trim().isEmpty ? null : _fiscalResponsibilitiesController.text.trim(),
        createdAt: _currentConfig?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await CompanyConfigService.updateCompanyConfig(updatedConfig);
      
      Get.snackbar(
        'Éxito', 
        'Configuración guardada correctamente',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
      Navigator.of(context).pop();
    } catch (e) {
      Get.snackbar('Error', 'Error guardando configuración: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ VERIFICAR PERMISOS DE ACCESO
    final permissionsService = Get.find<PermissionsService>();
    final currentUser = Get.find<AuthService>().currentUser;
    if (currentUser == null || !permissionsService.hasPermission(currentUser.role, Permission.accessCompanyConfig)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Acceso Denegado'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Acceso Denegado',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'No tienes permisos para acceder a la configuración de empresa.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'Solo usuarios con rol de mantenimiento pueden modificar estos datos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Empresa'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          // ✅ INDICADOR DE ROL DE MANTENIMIENTO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'MANTENIMIENTO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: _saveConfig,
            icon: const Icon(Icons.save),
            tooltip: 'Guardar configuración',
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const Text(
                    'Datos de la Empresa',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Nombre de la empresa
                  TextFormField(
                    controller: _companyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la Empresa *',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El nombre de la empresa es obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Dirección
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Dirección *',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'La dirección es obligatoria';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Teléfono
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono *',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El teléfono es obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  
                  // Sitio web
                  TextFormField(
                    controller: _websiteController,
                    decoration: const InputDecoration(
                      labelText: 'Sitio Web',
                      prefixIcon: Icon(Icons.web),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  
                  // NIT/RUT
                  TextFormField(
                    controller: _taxIdController,
                    decoration: const InputDecoration(
                      labelText: 'NIT/RUT',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // ✅ NUEVA SECCIÓN: DATOS PARA FACTURACIÓN ELECTRÓNICA
                  const Text(
                    'Datos para Facturación Electrónica DIAN',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Tipo de documento
                  TextFormField(
                    controller: _documentTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Documento *',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                      helperText: '31 = NIT (obligatorio para facturación electrónica)',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El tipo de documento es obligatorio para facturación electrónica';
                      }
                      if (value != '31') {
                        return 'Para facturación electrónica debe ser 31 (NIT)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Número de NIT
                  TextFormField(
                    controller: _nitNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Número de NIT *',
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(),
                      helperText: 'Solo números, sin guión ni puntos',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El número de NIT es obligatorio para facturación electrónica';
                      }
                      if (!RegExp(r'^\d+$').hasMatch(value)) {
                        return 'Solo debe contener números';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Dígito de verificación
                  TextFormField(
                    controller: _verificationDigitController,
                    decoration: const InputDecoration(
                      labelText: 'DV (Dígito de Verificación) *',
                      prefixIcon: Icon(Icons.verified),
                      border: OutlineInputBorder(),
                      helperText: 'Dígito de verificación del NIT',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El dígito de verificación es obligatorio para facturación electrónica';
                      }
                      if (!RegExp(r'^\d+$').hasMatch(value)) {
                        return 'Solo debe contener números';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Ciudad
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Ciudad *',
                      prefixIcon: Icon(Icons.location_city),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'La ciudad es obligatoria para facturación electrónica';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Departamento
                  TextFormField(
                    controller: _departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Departamento *',
                      prefixIcon: Icon(Icons.map),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El departamento es obligatorio para facturación electrónica';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // País
                  TextFormField(
                    controller: _countryController,
                    decoration: const InputDecoration(
                      labelText: 'País *',
                      prefixIcon: Icon(Icons.public),
                      border: OutlineInputBorder(),
                      helperText: 'Código de país (ej: CO para Colombia)',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El país es obligatorio para facturación electrónica';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Régimen fiscal
                  TextFormField(
                    controller: _fiscalRegimeController,
                    decoration: const InputDecoration(
                      labelText: 'Régimen Fiscal *',
                      prefixIcon: Icon(Icons.account_balance),
                      border: OutlineInputBorder(),
                      helperText: 'Común, simplificado, etc.',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El régimen fiscal es obligatorio para facturación electrónica';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Responsabilidades fiscales
                  TextFormField(
                    controller: _fiscalResponsibilitiesController,
                    decoration: const InputDecoration(
                      labelText: 'Responsabilidades Fiscales *',
                      prefixIcon: Icon(Icons.receipt_long),
                      border: OutlineInputBorder(),
                      helperText: 'O-13, I-23, etc. (separadas por coma)',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Las responsabilidades fiscales son obligatorias para facturación electrónica';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  const Text(
                    'Textos de Factura',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Texto de cabecera
                  TextFormField(
                    controller: _headerTextController,
                    decoration: const InputDecoration(
                      labelText: 'Texto de Cabecera *',
                      prefixIcon: Icon(Icons.text_fields),
                      border: OutlineInputBorder(),
                      helperText: 'Aparece en la parte superior de la factura',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El texto de cabecera es obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Texto de pie
                  TextFormField(
                    controller: _footerTextController,
                    decoration: const InputDecoration(
                      labelText: 'Texto de Pie *',
                      prefixIcon: Icon(Icons.text_fields),
                      border: OutlineInputBorder(),
                      helperText: 'Aparece en la parte inferior de la factura',
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El texto de pie es obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Vista previa
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vista Previa de Factura:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _headerTextController.text.isEmpty ? 'FACTURA DE VENTA' : _headerTextController.text,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(_companyNameController.text.isEmpty ? 'MI EMPRESA POS' : _companyNameController.text),
                        Text(_addressController.text.isEmpty ? 'Dirección de la empresa' : _addressController.text),
                        Text('Tel: ${_phoneController.text.isEmpty ? 'Teléfono' : _phoneController.text}'),
                        const SizedBox(height: 8),
                        const Text('----------------------------------------'),
                        const Text('Producto         \$15.00'),
                        const Text('----------------------------------------'),
                        const Text('TOTAL:           \$15.00'),
                        const SizedBox(height: 8),
                        Text(
                          _footerTextController.text.isEmpty ? 'Gracias por su compra' : _footerTextController.text,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveConfig,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Guardar Configuración'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _taxIdController.dispose();
    _headerTextController.dispose();
    _footerTextController.dispose();
    
    // ✅ DISPOSE DE NUEVOS CONTROLADORES
    _documentTypeController.dispose();
    _nitNumberController.dispose();
    _verificationDigitController.dispose();
    _cityController.dispose();
    _departmentController.dispose();
    _countryController.dispose();
    _fiscalRegimeController.dispose();
    _fiscalResponsibilitiesController.dispose();
    
    super.dispose();
  }
} 