// Módulo de Facturación Electrónica DIAN
// Este módulo es completamente independiente del POS principal

import 'package:flutter/material.dart';
import 'screens/electronic_invoice_screen.dart';
import 'screens/invoice_status_screen.dart';
import 'screens/pending_invoice_queue_screen.dart';
import 'controllers/electronic_invoice_controller.dart';
import 'models/electronic_document.dart';

class ElectronicInvoicingModule {
  static const String name = 'Facturación Electrónica';
  static const String description = 'Módulo para generación de documentos electrónicos según normativa DIAN';
  static const String version = '1.0.0';
  
  // Rutas del módulo
  static const String mainRoute = '/electronic-invoicing';
  static const String statusRoute = '/electronic-invoicing/status';
  static const String queueRoute = '/electronic-invoicing/queue';
  static const String clientRoute = '/electronic-invoicing/client';
  static const String productsRoute = '/electronic-invoicing/products';
  
  // Configuración del módulo
  static const Map<String, dynamic> config = {
    'requiresAuthorization': true,
    'permissions': ['electronic_invoicing'],
    'dependencies': ['clients', 'products'],
  };
  
  // Inicializar el módulo
  static void initialize() {
    print('🚀 Inicializando módulo de Facturación Electrónica...');
    // Aquí se pueden inicializar servicios, controladores, etc.
    print('✅ Módulo de Facturación Electrónica inicializado');
  }
  
  // Obtener rutas del módulo
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      mainRoute: (context) => const ElectronicInvoiceScreen(),
      statusRoute: (context) => const InvoiceStatusScreen(),
      queueRoute: (context) => const PendingInvoiceQueueScreen(),
      // clientRoute: (context) => const ClientScreen(),
      // productsRoute: (context) => const ProductsScreen(),
    };
  }
  
  // Verificar si el módulo está disponible
  static bool isAvailable() {
    // Aquí se pueden verificar dependencias, permisos, etc.
    return true;
  }
} 