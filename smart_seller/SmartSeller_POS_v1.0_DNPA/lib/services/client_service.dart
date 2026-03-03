import '../models/client.dart';
import 'sqlite_database_service.dart';

class ClientService {
  // Crear un nuevo cliente
  static Future<Client?> createClient({
    required String documentType,
    required String documentNumber,
    required String businessName,
    String? email,
    String? phone,
    String? address,
    required String fiscalResponsibility,
    String? city,
    String? department,
    String? country,
    String? postalCode,
    String? contactPerson,
    String? notes,
  }) async {
    try {
      // Validar que el documento no exista
      final existingClient = await SQLiteDatabaseService.getClientByDocument(documentNumber);
      if (existingClient != null) {
        throw Exception('Ya existe un cliente con el documento $documentNumber');
      }
      
      // Crear el cliente
      final client = Client(
        documentType: documentType,
        documentNumber: documentNumber,
        businessName: businessName,
        email: email,
        phone: phone,
        address: address,
        fiscalResponsibility: fiscalResponsibility,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        city: city,
        department: department,
        country: country,
        postalCode: postalCode,
        contactPerson: contactPerson,
        notes: notes,
      );
      
      // Validar el cliente
      if (!client.isValid) {
        throw Exception('Datos del cliente inválidos: ${client.validationErrors.join(', ')}');
      }
      
      // Guardar en la base de datos
      await SQLiteDatabaseService.createClient(client);
      
      return client;
    } catch (e) {
      print('❌ Error al crear cliente: $e');
      rethrow;
    }
  }
  
  // Buscar cliente por documento
  static Future<Client?> findClientByDocument(String documentNumber) async {
    try {
      return await SQLiteDatabaseService.getClientByDocument(documentNumber);
    } catch (e) {
      print('❌ Error al buscar cliente por documento: $e');
      return null;
    }
  }
  
  // Buscar cliente por ID
  static Future<Client?> findClientById(int id) async {
    try {
      return await SQLiteDatabaseService.getClientById(id);
    } catch (e) {
      print('❌ Error al buscar cliente por ID: $e');
      return null;
    }
  }
  
  // Buscar clientes (para autocompletado)
  static Future<List<Client>> searchClients(String query) async {
    try {
      if (query.trim().isEmpty) return [];
      
      return await SQLiteDatabaseService.searchClientsByBusinessName(query.trim());
    } catch (e) {
      print('❌ Error al buscar clientes: $e');
      return [];
    }
  }
  
  // Obtener todos los clientes
  static Future<List<Client>> getAllClients() async {
    try {
      return await SQLiteDatabaseService.getAllClients();
    } catch (e) {
      print('❌ Error al obtener clientes: $e');
      return [];
    }
  }
  
  // Actualizar cliente existente
  static Future<Client?> updateClient(Client client) async {
    try {
      // Validar que el cliente existe
      final existingClient = await SQLiteDatabaseService.getClientById(client.id!);
      if (existingClient == null) {
        throw Exception('Cliente no encontrado');
      }
      
      // Validar que el documento no esté en uso por otro cliente
      final clientWithSameDocument = await SQLiteDatabaseService.getClientByDocument(client.documentNumber);
      if (clientWithSameDocument != null && clientWithSameDocument.id != client.id) {
        throw Exception('Ya existe otro cliente con el documento ${client.documentNumber}');
      }
      
      // Validar el cliente
      if (!client.isValid) {
        throw Exception('Datos del cliente inválidos: ${client.validationErrors.join(', ')}');
      }
      
      // Actualizar fecha de modificación
      client.updatedAt = DateTime.now();
      
      // Actualizar en la base de datos
      await SQLiteDatabaseService.updateClient(client);
      
      return client;
    } catch (e) {
      print('❌ Error al actualizar cliente: $e');
      rethrow;
    }
  }
  
  // Eliminar cliente (marcar como inactivo)
  static Future<bool> deleteClient(int clientId) async {
    try {
      await SQLiteDatabaseService.deleteClient(clientId);
      return true;
    } catch (e) {
      print('❌ Error al eliminar cliente: $e');
      return false;
    }
  }
  
  // Verificar si un cliente existe
  static Future<bool> clientExists(String documentNumber) async {
    try {
      return await SQLiteDatabaseService.clientDocumentExists(documentNumber);
    } catch (e) {
      print('❌ Error al verificar cliente: $e');
      return false;
    }
  }
  
  // Obtener estadísticas del cliente
  static Future<Map<String, dynamic>> getClientStats() async {
    try {
      final clients = await SQLiteDatabaseService.getAllClients();
      return {
        'total_clients': clients.length,
        'active_clients': clients.where((c) => c.isActive).length,
        'inactive_clients': clients.where((c) => !c.isActive).length,
      };
    } catch (e) {
      print('❌ Error al obtener estadísticas de clientes: $e');
      return {
        'total_clients': 0,
        'active_clients': 0,
        'inactive_clients': 0,
      };
    }
  }
  
  // Validar NIT colombiano
  static bool validateNIT(String nit) {
    // Remover espacios y guiones
    nit = nit.replaceAll(RegExp(r'[\s-]'), '');
    
    // Verificar longitud
    if (nit.length < 8 || nit.length > 15) return false;
    
    // Verificar que solo contenga números
    if (!RegExp(r'^\d+$').hasMatch(nit)) return false;
    
    return true;
  }
  
  // Validar cédula de ciudadanía
  static bool validateCedula(String cedula) {
    // Remover espacios
    cedula = cedula.replaceAll(' ', '');
    
    // Verificar longitud
    if (cedula.length < 6 || cedula.length > 12) return false;
    
    // Verificar que solo contenga números
    if (!RegExp(r'^\d+$').hasMatch(cedula)) return false;
    
    return true;
  }
  
  // Validar email
  static bool validateEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
  
  // Validar teléfono colombiano
  static bool validatePhone(String phone) {
    // Remover espacios y caracteres especiales
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Verificar longitud (7-10 dígitos)
    if (phone.length < 7 || phone.length > 10) return false;
    
    // Verificar que solo contenga números
    if (!RegExp(r'^\d+$').hasMatch(phone)) return false;
    
    return true;
  }
} 