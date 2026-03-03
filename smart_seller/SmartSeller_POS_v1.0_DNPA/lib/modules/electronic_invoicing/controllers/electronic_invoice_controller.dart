import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../models/client.dart';
import '../../../models/product.dart';
import '../../../services/client_service.dart';

class ElectronicInvoiceController extends GetxController {
  // Variables observables para datos de factura
  final RxString selectedTab = 'Datos Factura'.obs;
  final RxString invoiceNumber = ''.obs;
  final RxString issueDate = ''.obs;
  final RxString dueDate = ''.obs;
  final RxString paymentMethod = 'Efectivo'.obs;
  final RxString observations = ''.obs;
  
  // Variables observables para cliente
  final RxString clientType = 'CUANTIAS MENORES'.obs;
  final RxString clientNit = ''.obs;
  final RxString clientName = ''.obs;
  final RxString clientAddress = ''.obs;
  final RxString clientPhone = ''.obs;
  final RxString clientEmail = ''.obs;
  
  // Variables observables para productos
  final RxList<Map<String, dynamic>> invoiceProducts = <Map<String, dynamic>>[].obs;
  final RxDouble subtotal = 0.0.obs;
  final RxDouble iva = 0.0.obs;
  final RxDouble total = 0.0.obs;
  
  // Estado del formulario
  final RxBool isLoading = false.obs;
  final RxBool isDraftSaved = false.obs;
  final RxBool isSentToDIAN = false.obs;
  
  // Validaciones
  final RxBool isFormValid = false.obs;
  final RxBool isClientValid = false.obs;
  
  @override
  void onInit() {
    super.onInit();
    _initializeDates();
    _calculateTotals();
  }
  
  void _initializeDates() {
    final now = DateTime.now();
    issueDate.value = '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';
    dueDate.value = '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';
  }
  
  void changeTab(String tabName) {
    selectedTab.value = tabName;
  }
  
  // Métodos para datos de factura
  void updateInvoiceNumber(String number) {
    invoiceNumber.value = number;
    _validateForm();
  }
  
  void updateIssueDate(String date) {
    issueDate.value = date;
    _validateForm();
  }
  
  void updateDueDate(String date) {
    dueDate.value = date;
    _validateForm();
  }
  
  void updatePaymentMethod(String method) {
    paymentMethod.value = method;
    _validateForm();
  }
  
  void updateObservations(String obs) {
    observations.value = obs;
  }
  
  // Métodos para datos de cliente
  void updateClientType(String type) {
    clientType.value = type;
    _validateClient();
  }
  
  void updateClientNit(String nit) {
    clientNit.value = nit;
    _validateClient();
  }
  
  void updateClientName(String name) {
    clientName.value = name;
    _validateClient();
  }
  
  void updateClientAddress(String address) {
    clientAddress.value = address;
  }
  
  void updateClientPhone(String phone) {
    clientPhone.value = phone;
  }
  
  void updateClientEmail(String email) {
    clientEmail.value = email;
  }
  
  // Métodos para productos
  void addProduct(Product product, {double quantity = 1.0}) {
    final existingIndex = invoiceProducts.indexWhere((p) => p['product'].id == product.id);
    
    if (existingIndex >= 0) {
      // Actualizar cantidad si el producto ya existe
      final currentQuantity = invoiceProducts[existingIndex]['quantity'];
      invoiceProducts[existingIndex]['quantity'] = currentQuantity + quantity;
    } else {
      // Agregar nuevo producto
      invoiceProducts.add({
        'product': product,
        'quantity': quantity,
        'unitPrice': product.price,
        'total': product.price * quantity,
      });
    }
    
    _calculateTotals();
  }
  
  void removeProduct(int index) {
    if (index >= 0 && index < invoiceProducts.length) {
      invoiceProducts.removeAt(index);
      _calculateTotals();
    }
  }
  
  void updateProductQuantity(int index, double quantity) {
    if (index >= 0 && index < invoiceProducts.length) {
      final product = invoiceProducts[index];
      product['quantity'] = quantity;
      product['total'] = product['unitPrice'] * quantity;
      invoiceProducts[index] = product;
      _calculateTotals();
    }
  }
  
  void _calculateTotals() {
    double sub = 0.0;
    for (final product in invoiceProducts) {
      sub += product['total'];
    }
    
    subtotal.value = sub;
    iva.value = sub * 0.19; // 19% IVA
    total.value = sub + iva.value;
  }
  
  void _validateForm() {
    isFormValid.value = invoiceNumber.value.isNotEmpty &&
                       issueDate.value.isNotEmpty &&
                       dueDate.value.isNotEmpty &&
                       paymentMethod.value.isNotEmpty;
  }
  
  void _validateClient() {
    if (clientType.value == 'CUANTIAS MENORES') {
      isClientValid.value = true; // No requiere validación para cuantías menores
    } else {
      isClientValid.value = clientNit.value.isNotEmpty && clientName.value.isNotEmpty;
    }
  }
  
  Future<void> saveDraft() async {
    try {
      isLoading.value = true;
      
      // Validar formulario básico
      if (!isFormValid.value) {
        Get.snackbar(
          'Error',
          'Por favor complete todos los campos obligatorios de la factura',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      // Simular guardado
      await Future.delayed(const Duration(seconds: 1));
      
      isDraftSaved.value = true;
      
      Get.snackbar(
        'Éxito',
        'Borrador guardado correctamente',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al guardar el borrador: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> sendToDIAN() async {
    try {
      isLoading.value = true;
      
      // Validar formulario completo
      if (!isFormValid.value) {
        Get.snackbar(
          'Error',
          'Por favor complete todos los campos obligatorios de la factura',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      if (!isClientValid.value) {
        Get.snackbar(
          'Error',
          'Por favor complete los datos del cliente',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      if (invoiceProducts.isEmpty) {
        Get.snackbar(
          'Error',
          'Debe agregar al menos un producto a la factura',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      // Simular envío a DIAN
      await Future.delayed(const Duration(seconds: 2));
      
      isSentToDIAN.value = true;
      
      Get.snackbar(
        'Éxito',
        'Factura enviada a DIAN correctamente',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
      // Limpiar formulario después del envío exitoso
      resetForm();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al enviar a DIAN: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
  
  void resetForm() {
    // Resetear datos de factura
    invoiceNumber.value = '';
    _initializeDates();
    paymentMethod.value = 'Efectivo';
    observations.value = '';
    
    // Resetear datos de cliente
    clientType.value = 'CUANTIAS MENORES';
    clientNit.value = '';
    clientName.value = '';
    clientAddress.value = '';
    clientPhone.value = '';
    clientEmail.value = '';
    
    // Resetear productos
    invoiceProducts.clear();
    _calculateTotals();
    
    // Resetear estados
    isDraftSaved.value = false;
    isSentToDIAN.value = false;
    
    // Validar formularios
    _validateForm();
    _validateClient();
  }
  
  // Método para buscar clientes
  Future<List<Client>> searchClients(String query) async {
    try {
      return await ClientService.searchClients(query);
    } catch (e) {
      print('Error al buscar clientes: $e');
      return [];
    }
  }
  
  // Método para cargar cliente seleccionado
  void loadClient(Client client) {
    clientNit.value = client.documentNumber;
    clientName.value = client.businessName;
    clientAddress.value = client.address ?? '';
    clientPhone.value = client.phone ?? '';
    clientEmail.value = client.email ?? '';
    clientType.value = 'CLIENTE REGISTRADO';
    _validateClient();
  }
} 