# 📋 DESCRIPCIÓN TÉCNICA DETALLADA - SmartSeller POS v2.0

## 📄 INFORMACIÓN GENERAL DEL SOFTWARE

### **Identificación del Programa:**
- **Nombre:** SmartSeller POS (Point of Sale)
- **Versión:** 2.0 Final
- **Fecha de Desarrollo:** Septiembre - Diciembre 2024
- **Desarrollador:** Oscar Mauricio Gonzalez
- **Tipo de Software:** Sistema de Punto de Venta Profesional
- **Categoría:** Software de Gestión Comercial
- **Plataforma:** Multiplataforma (Windows, Android, Web)

### **Propósito del Software:**
SmartSeller POS es un sistema integral de punto de venta diseñado para pequeñas y medianas empresas que requieren una solución completa para la gestión de ventas, inventario, clientes y facturación electrónica según los estándares de la DIAN (Colombia).

---

## 🎯 OBJETIVOS DEL SISTEMA

### **Objetivo Principal:**
Automatizar y optimizar los procesos de venta, inventario y facturación de empresas comerciales mediante una interfaz intuitiva y funcionalidades avanzadas.

### **Objetivos Específicos:**
1. **Gestión Eficiente de Ventas:** Procesar ventas de manera rápida y precisa
2. **Control de Inventario:** Mantener control automático del stock de productos
3. **Facturación Electrónica:** Generar facturas electrónicas según estándares DIAN
4. **Gestión de Clientes:** Mantener base de datos completa de clientes
5. **Reportes Profesionales:** Generar reportes detallados para toma de decisiones
6. **Control de Usuarios:** Sistema granular de permisos y roles

---

## 🏗️ ARQUITECTURA DEL SISTEMA

### **Arquitectura General:**
El sistema está construido siguiendo el patrón **Model-View-Controller (MVC)** con las siguientes capas:

#### **1. Capa de Presentación (View)**
- **Tecnología:** Flutter Widgets
- **Responsabilidad:** Interfaz de usuario y experiencia del usuario
- **Componentes:** Pantallas, widgets personalizados, navegación

#### **2. Capa de Lógica de Negocio (Controller)**
- **Tecnología:** GetX Controllers
- **Responsabilidad:** Lógica de negocio y gestión de estado
- **Componentes:** Controladores de pantallas, middleware de autenticación

#### **3. Capa de Datos (Model)**
- **Tecnología:** SQLite Database
- **Responsabilidad:** Persistencia de datos y operaciones CRUD
- **Componentes:** Servicios de base de datos, modelos de datos

### **Patrones de Diseño Implementados:**
- **Singleton:** Para servicios únicos (AuthService, DatabaseService)
- **Repository:** Para acceso a datos
- **Observer:** Para reactividad con GetX
- **Factory:** Para creación de objetos complejos
- **Strategy:** Para diferentes tipos de productos (unidad/peso)

---

## 🔧 COMPONENTES PRINCIPALES DEL SISTEMA

### **1. Módulo de Autenticación**
**Ubicación:** `lib/services/auth_service.dart`

**Funcionalidades:**
- Validación de credenciales de usuario
- Gestión de sesiones activas
- Encriptación de contraseñas
- Middleware de autenticación para rutas protegidas

**Procedimientos:**
1. **Login de Usuario:**
   - Validar credenciales contra base de datos
   - Generar token de sesión
   - Registrar actividad de login
   - Redirigir al dashboard principal

2. **Logout de Usuario:**
   - Invalidar token de sesión
   - Limpiar datos de usuario en memoria
   - Registrar actividad de logout
   - Redirigir a pantalla de login

3. **Validación de Sesión:**
   - Verificar token de sesión activo
   - Renovar sesión si es necesario
   - Bloquear acceso si sesión expirada

### **2. Módulo de Gestión de Productos**
**Ubicación:** `lib/screens/products_screen.dart`

**Funcionalidades:**
- CRUD completo de productos
- Gestión de inventario por unidad y peso
- Control de stock automático
- Categorización de productos
- Gestión de precios (costo y venta)

**Procedimientos:**
1. **Crear Producto:**
   - Validar datos de entrada (nombre, precio, stock)
   - Determinar tipo de producto (unidad/peso)
   - Asignar categoría y grupo
   - Calcular códigos automáticos
   - Guardar en base de datos
   - Actualizar inventario

2. **Actualizar Producto:**
   - Buscar producto por ID
   - Validar cambios permitidos
   - Actualizar información modificada
   - Recalcular stock si es necesario
   - Registrar cambios en auditoría

3. **Eliminar Producto:**
   - Verificar que no tenga ventas asociadas
   - Eliminar de base de datos
   - Actualizar inventario
   - Registrar eliminación en auditoría

4. **Control de Stock:**
   - Monitorear niveles de inventario
   - Generar alertas de stock bajo
   - Calcular rotación de productos
   - Actualizar disponibilidad en tiempo real

### **3. Módulo de Punto de Venta (POS)**
**Ubicación:** `lib/screens/pos_screen.dart`

**Funcionalidades:**
- Interfaz de venta rápida
- Búsqueda inteligente de productos
- Carrito de compras dinámico
- Balanza integrada para productos por peso
- Cálculo automático de totales e impuestos
- Múltiples métodos de pago
- Impresión automática de tickets

**Procedimientos:**
1. **Procesar Venta:**
   - Buscar productos por nombre o código
   - Agregar productos al carrito
   - Calcular subtotal, impuestos y total
   - Seleccionar método de pago
   - Procesar pago
   - Generar ticket de venta
   - Actualizar inventario
   - Registrar venta en base de datos

2. **Gestión de Carrito:**
   - Agregar productos con cantidad
   - Modificar cantidades
   - Eliminar productos del carrito
   - Calcular totales en tiempo real
   - Aplicar descuentos si corresponde

3. **Integración con Balanza:**
   - Detectar productos por peso
   - Simular lectura de peso
   - Calcular precio por peso
   - Actualizar total de venta

4. **Métodos de Pago:**
   - Efectivo (con cálculo de vuelto)
   - Tarjeta de débito/crédito
   - Transferencia bancaria
   - Cheque
   - Combinación de métodos

### **4. Módulo de Gestión de Clientes**
**Ubicación:** `lib/screens/customers_screen.dart`

**Funcionalidades:**
- Base de datos completa de clientes
- Validación de documentos (Cédula, NIT, RUT)
- Historial de compras por cliente
- Búsqueda avanzada de clientes
- Gestión de información de contacto

**Procedimientos:**
1. **Registrar Cliente:**
   - Validar tipo de documento
   - Verificar formato de documento
   - Validar unicidad del documento
   - Completar información personal
   - Guardar en base de datos
   - Generar código de cliente único

2. **Buscar Cliente:**
   - Búsqueda por documento
   - Búsqueda por nombre
   - Búsqueda por teléfono
   - Filtros avanzados
   - Resultados ordenados por relevancia

3. **Actualizar Información:**
   - Modificar datos de contacto
   - Actualizar dirección
   - Cambiar información fiscal
   - Registrar cambios en auditoría

4. **Historial de Compras:**
   - Consultar ventas por cliente
   - Calcular totales de compras
   - Generar reportes de cliente
   - Análisis de comportamiento de compra

### **5. Módulo de Facturación Electrónica DIAN**
**Ubicación:** `lib/modules/electronic_invoicing/`

**Funcionalidades:**
- Generación de facturas electrónicas
- Validación de datos fiscales según DIAN
- Envío de facturas a DIAN (simulado)
- Gestión de estados de facturación
- Cola de facturas pendientes
- Auditoría completa de operaciones

**Procedimientos:**
1. **Crear Factura Electrónica:**
   - Validar datos de la empresa
   - Completar información del cliente
   - Agregar productos a la factura
   - Calcular subtotal, IVA y total
   - Validar campos obligatorios DIAN
   - Generar número de factura único
   - Guardar como borrador o enviar

2. **Validación DIAN:**
   - Verificar formato de NIT
   - Validar dígito de verificación
   - Comprobar régimen fiscal
   - Verificar responsabilidades fiscales
   - Validar datos de ubicación

3. **Envío a DIAN:**
   - Simular envío a servicios DIAN
   - Generar CUFE (Código Único de Facturación Electrónica)
   - Registrar estado de envío
   - Manejar respuestas de DIAN
   - Actualizar estado de factura

4. **Gestión de Estados:**
   - Borrador
   - Enviada
   - Autorizada
   - Rechazada
   - Enviada a contingencia

### **6. Módulo de Reportes**
**Ubicación:** `lib/screens/reports_screen.dart`

**Funcionalidades:**
- Reportes de ventas (diario, semanal, mensual)
- Reportes de inventario
- Reportes de rentabilidad
- Reportes de clientes
- Exportación a PDF profesional
- Filtros avanzados por fecha, producto, cliente

**Procedimientos:**
1. **Generar Reporte de Ventas:**
   - Seleccionar período de tiempo
   - Aplicar filtros (producto, cliente, vendedor)
   - Consultar datos de ventas
   - Calcular totales y estadísticas
   - Generar gráficos y tablas
   - Exportar a PDF

2. **Reporte de Inventario:**
   - Consultar stock actual
   - Calcular valor de inventario
   - Identificar productos con stock bajo
   - Analizar rotación de productos
   - Generar recomendaciones

3. **Reporte de Rentabilidad:**
   - Calcular margen de ganancia por producto
   - Analizar productos más rentables
   - Identificar productos con pérdidas
   - Generar análisis de tendencias

### **7. Módulo de Gestión de Usuarios**
**Ubicación:** `lib/screens/users_screen.dart`

**Funcionalidades:**
- CRUD de usuarios del sistema
- Sistema granular de permisos
- Roles predefinidos (Admin, Vendedor, Mantenimiento)
- Control de acceso por módulo
- Auditoría de actividades de usuario

**Procedimientos:**
1. **Crear Usuario:**
   - Validar datos personales
   - Asignar rol de usuario
   - Configurar permisos específicos
   - Generar credenciales temporales
   - Enviar información de acceso

2. **Gestionar Permisos:**
   - Definir permisos por módulo
   - Asignar permisos por rol
   - Personalizar permisos por usuario
   - Validar acceso en tiempo real

3. **Auditoría de Usuarios:**
   - Registrar todas las actividades
   - Generar logs de acceso
   - Monitorear uso del sistema
   - Detectar actividades sospechosas

---

## 🗄️ GESTIÓN DE BASE DE DATOS

### **Tecnología:** SQLite
**Ubicación:** `lib/services/sqlite_database_service.dart`

### **Estructura de Tablas:**

#### **1. Tabla Users**
```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    full_name TEXT NOT NULL,
    email TEXT,
    role TEXT NOT NULL,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### **2. Tabla Products**
```sql
CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    price REAL NOT NULL,
    cost REAL,
    stock INTEGER DEFAULT 0,
    min_stock INTEGER DEFAULT 0,
    type TEXT NOT NULL, -- 'unit' o 'weight'
    category_id INTEGER,
    group_id INTEGER,
    barcode TEXT,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id),
    FOREIGN KEY (group_id) REFERENCES groups(id)
);
```

#### **3. Tabla Customers**
```sql
CREATE TABLE customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_type TEXT NOT NULL,
    document_number TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    address TEXT,
    city TEXT,
    department TEXT,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### **4. Tabla Sales**
```sql
CREATE TABLE sales (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER,
    user_id INTEGER NOT NULL,
    total REAL NOT NULL,
    subtotal REAL NOT NULL,
    tax REAL NOT NULL,
    payment_method TEXT NOT NULL,
    payment_amount REAL NOT NULL,
    change_amount REAL DEFAULT 0,
    sale_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);
```

#### **5. Tabla Sale_Items**
```sql
CREATE TABLE sale_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sale_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity REAL NOT NULL,
    unit_price REAL NOT NULL,
    total_price REAL NOT NULL,
    FOREIGN KEY (sale_id) REFERENCES sales(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);
```

### **Procedimientos de Base de Datos:**

#### **1. Inicialización:**
- Crear todas las tablas necesarias
- Insertar datos por defecto
- Configurar índices para optimización
- Establecer relaciones entre tablas

#### **2. Operaciones CRUD:**
- **Create:** Insertar nuevos registros con validación
- **Read:** Consultas optimizadas con filtros
- **Update:** Actualizar registros con auditoría
- **Delete:** Eliminación lógica para mantener integridad

#### **3. Respaldos:**
- Respaldo automático diario
- Respaldo manual bajo demanda
- Compresión de archivos de respaldo
- Rotación de respaldos antiguos

---

## 🔐 SISTEMA DE SEGURIDAD

### **Autenticación:**
- Encriptación de contraseñas con hash SHA-256
- Tokens de sesión con expiración automática
- Middleware de autenticación en todas las rutas protegidas
- Validación de credenciales en cada operación crítica

### **Autorización:**
- Sistema granular de permisos por módulo
- Roles predefinidos con permisos específicos
- Validación de permisos en tiempo real
- Bloqueo automático por intentos fallidos

### **Auditoría:**
- Registro de todas las operaciones críticas
- Logs de acceso y modificación de datos
- Trazabilidad completa de cambios
- Alertas por actividades sospechosas

### **Validación de Datos:**
- Sanitización de inputs del usuario
- Validación de formatos de documentos
- Verificación de rangos numéricos
- Prevención de inyección SQL

---

## 🖨️ SISTEMA DE IMPRESIÓN

### **Tecnología:** `lib/services/print_service.dart`

### **Funcionalidades:**
- Impresión de tickets de venta
- Impresión de facturas electrónicas
- Configuración de impresoras
- Soporte para impresoras térmicas y láser

### **Procedimientos:**
1. **Configurar Impresora:**
   - Detectar impresoras disponibles
   - Seleccionar impresora por defecto
   - Configurar parámetros de impresión
   - Probar conexión con impresora

2. **Imprimir Ticket:**
   - Generar contenido del ticket
   - Formatear texto para impresora térmica
   - Enviar comando de impresión
   - Verificar impresión exitosa

3. **Imprimir Factura:**
   - Generar PDF de factura
   - Configurar formato A4
   - Enviar a impresora láser
   - Registrar impresión en auditoría

---

## 📊 ALGORITMOS Y CÁLCULOS

### **1. Cálculo de Totales de Venta:**
```dart
// Algoritmo para calcular totales de venta
double calculateSaleTotal(List<SaleItem> items) {
  double subtotal = 0;
  for (var item in items) {
    subtotal += item.quantity * item.unitPrice;
  }
  
  double tax = subtotal * 0.19; // IVA 19%
  double total = subtotal + tax;
  
  return total;
}
```

### **2. Control de Stock:**
```dart
// Algoritmo para actualizar stock después de venta
void updateStockAfterSale(List<SaleItem> items) {
  for (var item in items) {
    Product product = getProductById(item.productId);
    product.stock -= item.quantity;
    
    if (product.stock <= product.minStock) {
      generateLowStockAlert(product);
    }
    
    updateProduct(product);
  }
}
```

### **3. Validación de Documentos:**
```dart
// Algoritmo para validar NIT colombiano
bool validateNIT(String nit) {
  if (nit.length < 8 || nit.length > 10) return false;
  
  String numbers = nit.substring(0, nit.length - 1);
  String checkDigit = nit.substring(nit.length - 1);
  
  int sum = 0;
  int[] weights = {71, 67, 59, 53, 47, 43, 41, 37, 29, 23, 19, 17, 13, 7, 3};
  
  for (int i = 0; i < numbers.length; i++) {
    sum += int.parse(numbers[i]) * weights[i];
  }
  
  int calculatedDigit = sum % 11;
  if (calculatedDigit < 2) {
    return checkDigit == calculatedDigit.toString();
  } else {
    return checkDigit == (11 - calculatedDigit).toString();
  }
}
```

---

## 🚀 PROCEDIMIENTOS DE INSTALACIÓN Y CONFIGURACIÓN

### **1. Instalación del Sistema:**
1. **Requisitos del Sistema:**
   - Windows 10/11 (64-bit)
   - 4GB RAM mínimo (8GB recomendado)
   - 2GB espacio libre en disco
   - Conexión a internet (opcional)

2. **Proceso de Instalación:**
   - Extraer archivos del sistema
   - Ejecutar `smart_seller.exe` como administrador
   - El sistema se instala automáticamente
   - Crear base de datos inicial
   - Configurar usuario administrador por defecto

### **2. Configuración Inicial:**
1. **Primer Acceso:**
   - Usuario: `admin`
   - Contraseña: `123456`
   - Cambiar contraseña inmediatamente

2. **Configuración de Empresa:**
   - Completar datos básicos de la empresa
   - Configurar datos fiscales para DIAN
   - Personalizar textos de facturación
   - Configurar métodos de pago

3. **Configuración de Usuarios:**
   - Crear usuarios del sistema
   - Asignar roles y permisos
   - Configurar usuarios vendedores

### **3. Configuración de Productos:**
1. **Categorías:**
   - Crear categorías de productos
   - Organizar productos por grupos
   - Configurar códigos de barras

2. **Productos Iniciales:**
   - Agregar productos básicos
   - Configurar precios de costo y venta
   - Establecer niveles de stock mínimo

### **4. Configuración de Impresión:**
1. **Impresora de Tickets:**
   - Conectar impresora térmica
   - Configurar puerto de comunicación
   - Probar impresión de tickets

2. **Impresora de Facturas:**
   - Configurar impresora láser
   - Establecer formato A4
   - Probar impresión de facturas

---

## 🔧 PROCEDIMIENTOS DE MANTENIMIENTO

### **1. Respaldo de Datos:**
- **Automático:** Diario a las 23:00
- **Manual:** Desde el menú de configuración
- **Ubicación:** `C:\SmartSellerPOS\Backups\`
- **Retención:** 30 días

### **2. Actualización del Sistema:**
- Verificación automática de actualizaciones
- Descarga e instalación automática
- Respaldo antes de actualizar
- Restauración en caso de problemas

### **3. Limpieza de Base de Datos:**
- Eliminación de registros antiguos
- Optimización de índices
- Compresión de archivos
- Verificación de integridad

### **4. Monitoreo del Sistema:**
- Verificación de espacio en disco
- Monitoreo de uso de memoria
- Detección de errores
- Generación de alertas

---

## 📈 MÉTRICAS Y RENDIMIENTO

### **Métricas de Rendimiento:**
- **Tiempo de respuesta:** < 200ms para operaciones básicas
- **Tiempo de carga:** < 3 segundos para inicio del sistema
- **Capacidad:** Hasta 10,000 productos y 100,000 ventas
- **Concurrencia:** Hasta 5 usuarios simultáneos

### **Optimizaciones Implementadas:**
- Índices en base de datos para consultas rápidas
- Caché de productos frecuentemente consultados
- Lazy loading de datos no críticos
- Compresión de imágenes y archivos

---

## 🚨 MANEJO DE ERRORES Y EXCEPCIONES

### **Tipos de Errores:**
1. **Errores de Validación:** Datos incorrectos del usuario
2. **Errores de Base de Datos:** Problemas de conexión o consulta
3. **Errores de Sistema:** Problemas de hardware o sistema operativo
4. **Errores de Red:** Problemas de conectividad

### **Procedimientos de Manejo:**
1. **Captura de Errores:** Try-catch en operaciones críticas
2. **Logging:** Registro detallado de errores
3. **Notificación:** Alertas al usuario sobre errores
4. **Recuperación:** Procedimientos automáticos de recuperación

---

## 🔄 INTEGRACIÓN CON SISTEMAS EXTERNOS

### **1. Balanzas Electrónicas:**
- Comunicación por puerto serial
- Protocolo de comunicación estándar
- Lectura automática de peso
- Integración con productos por peso

### **2. Impresoras:**
- Soporte para impresoras térmicas
- Compatibilidad con impresoras láser
- Configuración automática de puertos
- Manejo de diferentes formatos

### **3. Servicios DIAN:**
- Integración con servicios de facturación electrónica
- Envío automático de facturas
- Recepción de respuestas de autorización
- Manejo de estados de facturación

---

## 📋 PROCEDIMIENTOS DE TESTING

### **1. Testing Unitario:**
- Pruebas de funciones individuales
- Validación de algoritmos de cálculo
- Verificación de validaciones de datos
- Testing de servicios de base de datos

### **2. Testing de Integración:**
- Pruebas de comunicación entre módulos
- Validación de flujos completos de venta
- Testing de integración con impresoras
- Verificación de respaldos y restauración

### **3. Testing de Usuario:**
- Pruebas de interfaz de usuario
- Validación de experiencia del usuario
- Testing de rendimiento bajo carga
- Verificación de compatibilidad

---

## 📊 DOCUMENTACIÓN TÉCNICA ADICIONAL

### **Diagramas de Arquitectura:**
- Diagrama de componentes del sistema
- Diagrama de flujo de datos
- Diagrama de casos de uso
- Diagrama de base de datos

### **APIs y Servicios:**
- Documentación de servicios internos
- Especificación de interfaces
- Protocolos de comunicación
- Formatos de datos

### **Configuración Avanzada:**
- Parámetros de configuración del sistema
- Variables de entorno
- Archivos de configuración
- Opciones de personalización

---

**SmartSeller POS v2.0** - Sistema de Punto de Venta Profesional  
*Desarrollado con Flutter y SQLite para máxima compatibilidad y rendimiento*

**Fecha de Documentación:** Diciembre 2024  
**Versión del Sistema:** 2.0 Final  
**Desarrollador:** Oscar Mauricio Gonzalez  
**Licencia:** Propietaria
