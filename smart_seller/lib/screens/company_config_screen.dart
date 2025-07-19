import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/company_config.dart';
import '../services/company_config_service.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Empresa'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
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
    super.dispose();
  }
} 