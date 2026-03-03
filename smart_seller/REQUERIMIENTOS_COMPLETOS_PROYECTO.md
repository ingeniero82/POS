# 📋 REQUERIMIENTOS COMPLETOS DEL PROYECTO - Smart Seller POS v2.0

## 📌 INFORMACIÓN GENERAL DEL PROYECTO

- **Nombre del Software:** Smart Seller POS (Point of Sale)
- **Versión:** 2.0 Final
- **Tecnología Principal:** Flutter/Dart
- **Base de Datos:** SQLite
- **Plataforma Principal:** Windows 10/11 (64-bit)
- **Arquitectura:** Model-View-Controller (MVC)
- **Fecha:** Diciembre 2024

---

## 🖥️ REQUERIMIENTOS DEL SISTEMA (PARA EJECUTAR EL PROGRAMA)

### Requisitos Mínimos del Cliente:
- **Sistema Operativo:** Windows 10 (64-bit) o superior
- **Arquitectura:** Solo 64-bit (x64)
- **RAM:** Mínimo 4GB (8GB recomendado)
- **Espacio en Disco:** Mínimo 2GB libres
- **Procesador:** Intel Core i3 o equivalente
- **Permisos:** Administrador (para instalación)

### Dependencias Externas Requeridas:
1. **Visual C++ Redistributable 2015-2022 (x64)**
   - Descarga: https://aka.ms/vs/17/release/vc_redist.x64.exe
   - **CRÍTICO:** Sin esto el programa NO funcionará
   - Se instala automáticamente con el instalador profesional

2. **Windows Defender / Antivirus**
   - Puede bloquear la ejecución inicialmente
   - Requiere permitir la ejecución manualmente

---

## 💻 REQUERIMIENTOS DE DESARROLLO

### Software Necesario para Desarrollar:

1. **Flutter SDK**
   - Versión: 3.16.0 o superior
   - Descarga: https://flutter.dev/docs/get-started/install/windows
   - Requiere: Dart SDK 3.0.0 o superior

2. **Dart SDK**
   - Versión: >=3.0.0 <4.0.0
   - Incluido con Flutter SDK

3. **Visual Studio 2022** (para compilar en Windows)
   - Con componentes:
     - Desktop development with C++
     - Windows 10/11 SDK
   - Descarga: https://visualstudio.microsoft.com/downloads/

4. **Git** (opcional, para control de versiones)
   - Descarga: https://git-scm.com/download/win

5. **Inno Setup 6** (para crear instalador profesional .EXE)
   - Descarga: https://jrsoftware.org/isdl.php
   - **Opcional:** Solo si quieres crear instalador .EXE con interfaz gráfica

### Herramientas de Desarrollo:
- **Editor de Código:** Visual Studio Code o Android Studio
- **Extensiones Recomendadas:**
  - Flutter
  - Dart
  - Flutter Widget Snippets

---

## 📦 DEPENDENCIAS DEL PROYECTO (pubspec.yaml)

### Dependencias Principales:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  cupertino_icons: ^1.0.2
  get: ^4.6.6                    # Gestión de estado y navegación
  path_provider: ^2.1.1         # Rutas del sistema
  intl: ^0.20.2                  # Internacionalización y formato
  shared_preferences: ^2.2.2      # Almacenamiento local de configuraciones
  file_picker: ^6.1.1            # Selección de archivos
  excel: ^2.1.0                  # Exportación a Excel
  csv: ^5.0.2                    # Exportación a CSV
  pdf: ^3.10.7                   # Generación de PDFs
  sqflite: ^2.3.0                # Base de datos SQLite
  sqlite3_flutter_libs: ^0.5.0   # Librerías SQLite para Flutter
  path: ^1.8.3                    # Manipulación de rutas
  sqflite_common_ffi: ^2.3.6      # SQLite FFI para Windows
  flutter_typeahead: ^4.0.0      # Búsqueda con autocompletado
  libserialport: ^0.3.0+1        # Comunicación con balanzas electrónicas
  cached_network_image: ^3.3.0   # Caché de imágenes
  image_picker: ^1.0.4           # Selección de imágenes
  crypto: ^3.0.3                 # Encriptación SHA-256

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0          # Linter de código
  build_runner: ^2.4.6           # Generador de código
```

### Descripción de Dependencias Clave:

- **get (^4.6.6):** Gestión de estado, navegación y dependencias
- **sqflite (^2.3.0):** Base de datos SQLite local
- **pdf (^3.10.7):** Generación de facturas y reportes en PDF
- **excel (^2.1.0):** Exportación de datos a Excel
- **libserialport (^0.3.0+1):** Integración con balanzas electrónicas
- **crypto (^3.0.3):** Encriptación de contraseñas (SHA-256)

---

## 🏗️ ARQUITECTURA Y ESTRUCTURA DEL PROYECTO

### Estructura de Carpetas:

```
smart_seller/
├── lib/
│   ├── main.dart                    # Punto de entrada
│   ├── controllers/                 # Controladores GetX
│   ├── middleware/                  # Middleware de autenticación
│   ├── models/                      # Modelos de datos
│   ├── modules/                     # Módulos especializados
│   │   ├── accounting/              # Módulo contable
│   │   └── electronic_invoicing/    # Facturación electrónica DIAN
│   ├── screens/                     # Pantallas de la aplicación
│   ├── services/                    # Servicios de negocio
│   ├── utils/                       # Utilidades
│   └── widgets/                     # Componentes reutilizables
├── assets/
│   └── images/                      # Imágenes del proyecto
├── instalador/                      # Scripts de instalación
│   ├── SmartSellerPOS_Installer.iss # Script Inno Setup
│   ├── crear_instalador.bat        # Crear instalador
│   └── verificar_archivos.bat       # Verificar archivos
├── build/                           # Archivos compilados
│   └── windows/
│       └── x64/
│           └── runner/
│               └── Release/         # Ejecutables finales
└── pubspec.yaml                     # Configuración del proyecto
```

### Patrón Arquitectónico:
- **MVC (Model-View-Controller)**
- **Gestión de Estado:** GetX
- **Inyección de Dependencias:** GetX

---

## 🔧 SERVICIOS PRINCIPALES IMPLEMENTADOS

### 1. SQLiteDatabaseService
- **Ubicación:** `lib/services/sqlite_database_service.dart`
- **Función:** Gestión completa de la base de datos SQLite
- **Responsabilidades:**
  - Inicialización de la base de datos
  - Creación de tablas y migraciones
  - Operaciones CRUD
  - Creación de usuarios por defecto (admin, supervisor)

### 2. AuthService
- **Ubicación:** `lib/services/auth_service.dart`
- **Función:** Autenticación y gestión de sesiones
- **Responsabilidades:**
  - Login/Logout
  - Validación de credenciales
  - Gestión de sesión de usuario

### 3. PermissionsService
- **Ubicación:** `lib/services/permissions_service.dart`
- **Función:** Control granular de permisos
- **Roles Implementados:**
  - Administrador (admin)
  - Supervisor
  - Vendedor
  - Mantenimiento

### 4. DatabaseMaintenanceService
- **Ubicación:** `lib/services/database_maintenance_service.dart`
- **Función:** Mantenimiento automático de la base de datos
- **Funcionalidades:**
  - Optimización (VACUUM, ANALYZE) - **NO borra datos**
  - Limpieza de datos antiguos (opcional)
  - Creación de respaldos
  - Estadísticas de la base de datos

### 5. ConfigService
- **Ubicación:** `lib/services/config_service.dart`
- **Función:** Configuración global de la aplicación
- **Configuraciones:**
  - Mantenimiento automático (activar/desactivar)
  - Migración de base de datos

### 6. PrintService
- **Ubicación:** `lib/services/print_service.dart`
- **Función:** Impresión de tickets y facturas
- **Soporte:** Impresoras térmicas y láser

### 7. CompanyConfigService
- **Ubicación:** `lib/services/company_config_service.dart`
- **Función:** Configuración de datos de la empresa
- **Datos:** Información fiscal para facturación electrónica

### 8. ReportsService
- **Ubicación:** `lib/services/reports_service.dart`
- **Función:** Generación de reportes
- **Tipos:** Ventas, inventario, clientes, etc.

### 9. PDFReportsService
- **Ubicación:** `lib/services/pdf_reports_service.dart`
- **Función:** Generación de reportes en PDF

### 10. ScaleService
- **Ubicación:** `lib/services/scale_service_real.dart`
- **Función:** Integración con balanzas electrónicas
- **Protocolo:** Comunicación serial (libserialport)

---

## 📱 PANTALLAS PRINCIPALES IMPLEMENTADAS

### Pantallas del Sistema:

1. **LoginScreen** (`lib/screens/login_screen.dart`)
   - Autenticación de usuarios
   - Credenciales por defecto: admin / 123456

2. **DashboardScreen** (`lib/screens/dashboard_screen.dart`)
   - Panel principal con acceso a todos los módulos
   - Navegación por tarjetas

3. **PosScreen** (`lib/screens/pos_screen.dart`)
   - Punto de venta principal
   - Carrito de compras
   - Integración con balanza
   - Múltiples métodos de pago

4. **ProductsScreen** (`lib/screens/products_screen.dart`)
   - Gestión de inventario
   - Productos por unidad y por peso
   - Control de stock

5. **CustomersScreen** (`lib/screens/customers_screen.dart`)
   - Base de datos de clientes
   - Validación de documentos

6. **UsersScreen** (`lib/screens/users_screen.dart`)
   - Gestión de usuarios del sistema
   - Asignación de roles

7. **ReportsScreen** (`lib/screens/reports_screen.dart`)
   - Generación de reportes
   - Exportación a PDF/Excel

8. **CompanyConfigScreen** (`lib/screens/company_config_screen.dart`)
   - Configuración de empresa
   - **Mantenimiento automático (activar/desactivar)**

9. **SuppliersScreen** (`lib/screens/suppliers_screen.dart`)
   - Gestión de proveedores

10. **CashPickupsScreen** (`lib/screens/cash_pickups_screen.dart`)
    - Arqueos de caja

11. **GroupsScreen** (`lib/screens/groups_screen.dart`)
    - Gestión de grupos de productos

---

## 🎯 FUNCIONALIDADES PRINCIPALES IMPLEMENTADAS

### 1. Módulo de Punto de Venta (POS)
- ✅ Interfaz táctil y por teclado
- ✅ Búsqueda de productos (nombre, código de barras)
- ✅ Carrito de compras dinámico
- ✅ Productos por unidad y por peso
- ✅ Integración con balanzas electrónicas
- ✅ Cálculo automático de subtotales, IVA y totales
- ✅ Múltiples métodos de pago
- ✅ Impresión de tickets
- ✅ Gestión de descuentos con autorización
- ✅ Historial de transacciones

### 2. Módulo de Inventario
- ✅ Control completo de productos
- ✅ Categorías y grupos
- ✅ Productos por unidad y por peso
- ✅ Control de stock con alertas
- ✅ Precios de costo y venta
- ✅ Movimientos de inventario
- ✅ Códigos de barras
- ✅ Importación desde Excel/CSV
- ✅ Reportes de valorización

### 3. Módulo de Clientes
- ✅ Base de datos de clientes
- ✅ Validación de documentos (Cédula, NIT)
- ✅ Historial de compras
- ✅ Búsqueda avanzada

### 4. Módulo de Usuarios y Permisos
- ✅ Gestión de usuarios
- ✅ Sistema de roles (Admin, Supervisor, Vendedor, Mantenimiento)
- ✅ Permisos granulares
- ✅ Autenticación con encriptación SHA-256

### 5. Módulo de Reportes
- ✅ Reportes de ventas
- ✅ Reportes de inventario
- ✅ Reportes de clientes
- ✅ Exportación a PDF
- ✅ Exportación a Excel/CSV

### 6. Módulo Contable
- ✅ Cuentas por cobrar
- ✅ Cuentas por pagar
- ✅ Movimientos de caja
- ✅ Sesiones de caja
- ✅ Reportes contables

### 7. Módulo de Facturación Electrónica
- ✅ Integración con DIAN (Colombia)
- ✅ Generación de facturas electrónicas
- ✅ Cola de facturas pendientes
- ✅ Estado de facturas
- ✅ Configuración del sistema

### 8. Mantenimiento de Base de Datos
- ✅ **Optimización automática (VACUUM, ANALYZE)**
  - **IMPORTANTE:** NO borra datos, solo reorganiza
  - Se ejecuta automáticamente si está habilitado
  - Configurable desde Configuración de Empresa
- ✅ Limpieza de datos antiguos (opcional)
- ✅ Creación de respaldos
- ✅ Estadísticas de la base de datos

---

## 📦 PROCESO DE INSTALACIÓN

### Opción 1: Instalador ZIP (Simple)
1. Ejecutar: `CREAR_INSTALADOR_SIMPLE.bat`
2. Se crea: `SmartSellerPOS_Instalador.zip`
3. Cliente extrae y ejecuta `INSTALAR.bat` como administrador

### Opción 2: Instalador Profesional .EXE (Recomendado)
1. Instalar Inno Setup 6
2. Ejecutar: `CREAR_INSTALADOR_EXE.bat`
3. Se crea: `SmartSellerPOS_Setup_v2.0.exe`
4. Cliente ejecuta el .EXE (interfaz gráfica)

### Archivos del Instalador:
- `smart_seller.exe` - Ejecutable principal
- `*.dll` - Todas las librerías DLL necesarias
- `data/` - Carpeta con recursos de Flutter
- `icudtl.dat` - Datos de internacionalización

### Requisitos del Instalador:
- Permisos de administrador
- Visual C++ Redistributable (se instala automáticamente)
- Windows 10/11 (64-bit)

---

## 🔐 SEGURIDAD IMPLEMENTADA

### Encriptación:
- **Contraseñas:** SHA-256 (irreversible)
- **Almacenamiento:** Base de datos SQLite local

### Autenticación:
- Sistema de login con validación
- Sesiones de usuario
- Middleware de autenticación en rutas protegidas

### Permisos:
- Sistema granular de permisos por rol
- Control de acceso a funcionalidades
- Validación de permisos en cada acción

---

## 📊 BASE DE DATOS

### Tecnología:
- **SQLite** (base de datos local)
- **Ubicación:** `%USERPROFILE%\Documents\smart_seller.db`

### Tablas Principales:
- `users` - Usuarios del sistema
- `products` - Productos e inventario
- `sales` - Ventas realizadas
- `sale_items` - Items de cada venta
- `customers` - Clientes
- `inventory_movements` - Movimientos de inventario
- `suppliers` - Proveedores
- `accounting_entries` - Entradas contables
- `cash_sessions` - Sesiones de caja
- `company_config` - Configuración de empresa
- Y más...

### Mantenimiento:
- **Optimización automática:** VACUUM y ANALYZE (NO borra datos)
- **Respaldos:** Creación automática de respaldos
- **Limpieza:** Opcional, configurable por el usuario

---

## 🛠️ HERRAMIENTAS Y SCRIPTS DE DESARROLLO

### Scripts de Instalación:
1. **INSTALAR_EN_WINDOWS.bat**
   - Instalador por script (sin interfaz gráfica)
   - Copia archivos, crea accesos directos, registra en Windows

2. **CREAR_INSTALADOR_SIMPLE.bat**
   - Crea instalador ZIP portable

3. **CREAR_INSTALADOR_EXE.bat**
   - Crea instalador profesional .EXE (requiere Inno Setup)

4. **verificar_archivos.bat**
   - Verifica que todos los archivos necesarios estén presentes

5. **EJECUTAR_Y_VER_ERROR.bat**
   - Diagnóstico de errores en el cliente

### Scripts de Compilación:
1. **crear_instalador.bat** (en carpeta `instalador/`)
   - Compila la aplicación Flutter
   - Crea el instalador con Inno Setup

---

## 📝 CONFIGURACIONES IMPORTANTES

### Configuración de Mantenimiento Automático:
- **Ubicación:** Configuración de Empresa → Mantenimiento Automático
- **Función:** Optimiza la base de datos automáticamente
- **Importante:** NO borra datos, solo reorganiza
- **Activación/Desactivación:** Manual por el administrador
- **Permisos:** Solo usuarios con `modifySettings`

### Usuarios por Defecto:
- **admin** / **123456** (Administrador)
- **supervisor** / **123456** (Supervisor)

### Configuración de Empresa:
- Datos fiscales
- Información para facturación electrónica
- Configuración de impresora

---

## ⚠️ CONSIDERACIONES IMPORTANTES

### Para el Desarrollador:
1. **Compilación:** Siempre compilar con `flutter build windows --release`
2. **Dependencias:** Verificar que todas las DLL estén incluidas
3. **Instalador:** Probar en equipo limpio antes de entregar al cliente
4. **Visual C++:** Asegurarse de que el instalador lo incluya

### Para el Cliente:
1. **Visual C++ Redistributable:** CRÍTICO, sin esto no funciona
2. **Permisos de Administrador:** Necesarios para instalación
3. **Windows Defender:** Puede bloquear inicialmente
4. **Reinicio:** Puede ser necesario después de instalar Visual C++

### Mantenimiento de Base de Datos:
- **Optimización:** NO borra datos, solo reorganiza
- **Configuración:** Se puede activar/desactivar manualmente
- **Seguridad:** Solo usuarios con permisos pueden cambiar la configuración

---

## 📚 DOCUMENTACIÓN ADICIONAL

### Archivos de Documentación en el Proyecto:
- `GUIA_INSTALACION_POS.md` - Guía de instalación
- `instalador/INSTRUCCIONES_CLIENTE.md` - Instrucciones para el cliente
- `instalador/LEEME_INSTALADOR.md` - Información del instalador
- `D:\losoft\PARA_CLIENTE\LEEME_ESTO_PRIMERO.txt` - Guía rápida
- `D:\losoft\PARA_CLIENTE\SOLUCION_DEFINITIVA.txt` - Soluciones comunes

---

## ✅ CHECKLIST DE REQUERIMIENTOS

### Para Desarrollar:
- [x] Flutter SDK instalado
- [x] Dart SDK instalado
- [x] Visual Studio 2022 instalado
- [x] Todas las dependencias en `pubspec.yaml`
- [x] Inno Setup (opcional, para instalador .EXE)

### Para Compilar:
- [x] Ejecutar `flutter pub get`
- [x] Ejecutar `flutter build windows --release`
- [x] Verificar archivos en `build/windows/x64/runner/Release/`

### Para Instalar en Cliente:
- [x] Windows 10/11 (64-bit)
- [x] Permisos de administrador
- [x] Visual C++ Redistributable instalado
- [x] Espacio en disco suficiente

---

## 🎯 RESUMEN EJECUTIVO

**Smart Seller POS v2.0** es un sistema de punto de venta completo desarrollado en Flutter para Windows, con las siguientes características principales:

- ✅ Sistema POS completo con múltiples métodos de pago
- ✅ Gestión de inventario avanzada
- ✅ Base de datos SQLite local
- ✅ Sistema de usuarios y permisos granular
- ✅ Facturación electrónica (DIAN)
- ✅ Módulo contable
- ✅ Reportes en PDF y Excel
- ✅ Mantenimiento automático de base de datos (configurable)
- ✅ Instalador profesional para Windows
- ✅ Integración con balanzas electrónicas

**Requerimientos críticos:**
- Windows 10/11 (64-bit)
- Visual C++ Redistributable 2015-2022
- Permisos de administrador para instalación

---

**Documento generado:** Diciembre 2024  
**Versión del Proyecto:** 2.0 Final


