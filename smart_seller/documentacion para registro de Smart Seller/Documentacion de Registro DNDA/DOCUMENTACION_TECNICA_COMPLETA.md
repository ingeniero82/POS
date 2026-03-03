# DESCRIPCIÓN TÉCNICA

## Sistema de Punto de Venta SmartSeller POS v1.0

**Autor:** Oscar Mauricio González Montenegro  
**Fecha:** septiembre 2025  
**Versión:** 1.0  
**País de origen:** Colombia

---

## Contenido

1. Descripción general del software
2. Arquitectura técnica
   - 2.1 Patrón de arquitectura
   - 2.2 Capas del sistema
3. Tecnologías utilizadas
   - 3.1 Lenguaje y framework de desarrollo
   - 3.2 Base de datos
   - 3.3 Seguridad
   - 3.4 Generación de documentos
   - 3.5 Interfaz de usuario
   - 3.6 Hardware y periféricos
4. Funciones técnicas principales
   - 4.1 Procesamiento de transacciones
   - 4.2 Gestión de inventario
   - 4.3 Gestión de clientes
   - 4.4 Facturación electrónica (módulo en desarrollo)
   - 4.5 Reportes y contabilidad
   - 4.6 Gestión de usuarios y seguridad
   - 4.7 Configuración del sistema
5. Modelo de datos
   - 5.1 Tablas principales
   - 5.2 Relaciones entre tablas
6. Flujo de funcionamiento
   - 6.1 Proceso de venta
   - 6.2 Proceso de facturación electrónica (simulado)
   - 6.3 Proceso de gestión de inventario
7. Características de seguridad
   - 7.1 Encriptación
   - 7.2 Autenticación
   - 7.3 Autorización
   - 7.4 Validación de datos
   - 7.5 Auditoría
8. Plataformas soportadas
9. Requisitos del sistema
10. Módulos del sistema
   - 10.1 Módulo de punto de venta (POS)
   - 10.2 Módulo de gestión de inventario
   - 10.3 Módulo de gestión de clientes
   - 10.4 Módulo de facturación electrónica (en desarrollo)
   - 10.5 Módulo de reportes
   - 10.6 Módulo de usuarios y permisos
   - 10.7 Módulo de configuración (en proceso)
   - 10.8 Módulo "Datos de empresa"
11. Conclusiones
12. Guía de instalación y configuración
   - 12.1 Requisitos previos
   - 12.2 Pasos de instalación para desarrollo
   - 12.3 Configuración opcional
13. Estructura del proyecto
14. Despliegue y distribución (escritorio)
   - 14.1 Generación del ejecutable de Windows
   - 14.2 Paquetización
   - 14.3 Actualizaciones
15. Pruebas y control de calidad
   - 15.1 Pruebas automatizadas
   - 15.2 Pruebas manuales
   - 15.3 Seguimiento de calidad
16. Mantenimiento y roadmap
   - 16.1 Mantenimiento programado
   - 16.2 Evolución planificada
17. Anexos y referencias
18. Historial de versiones

---

## 1. Descripción general del software

SmartSeller POS v1.0 es un sistema integral de punto de venta desarrollado específicamente para pequeñas y medianas empresas en Colombia. El software permite la gestión completa de operaciones comerciales, incluyendo ventas, inventario, clientes y facturación electrónica según los estándares de la DIAN (Dirección de Impuestos y Aduanas Nacionales) (en proceso de prueba).

El sistema está diseñado con una arquitectura modular que facilita su mantenimiento, escalabilidad y extensión de funcionalidades. Utiliza tecnologías modernas de desarrollo multiplataforma para garantizar un rendimiento óptimo en diferentes entornos de trabajo.

## 2. Arquitectura técnica

### 2.1 Patrón de arquitectura

El sistema implementa el patrón Model-View-Controller (MVC) que separa claramente las responsabilidades entre:

- **Model (Modelo):** Representa los datos y la lógica de negocio.
- **View (Vista):** Interfaz de usuario y presentación.
- **Controller (Controlador):** Gestiona la interacción entre modelo y vista.

### 2.2 Capas del sistema

**Capa 1: Interfaz de usuario (View)**
- Pantallas principales: Login, Dashboard, Punto de Venta, Inventario, Clientes, Reportes, Configuración.
- Widgets personalizados reutilizables.
- Sistema de navegación fluida basado en rutas.
- Diseño responsive adaptado a diferentes tamaños de pantalla.

**Capa 2: Lógica de negocio (Controller)**
- Controladores de estado utilizando GetX framework.
- Servicios especializados:
  - Autenticación y autorización.
  - Gestión de base de datos.
  - Generación de reportes (PDF, Excel).
  - Comunicación con impresoras.
  - Validación de datos fiscales.
- Middleware de seguridad para protección de rutas.

**Capa 3: Acceso a datos (Model)**
- Base de datos SQLite local para almacenamiento persistente.
- Modelos de datos estructurados y tipados.
- Operaciones CRUD (Create, Read, Update, Delete) optimizadas.
- Migraciones de esquema de base de datos.

## 3. Tecnologías utilizadas

### 3.1 Lenguaje y framework de desarrollo
- Flutter 3.16.0+: framework multiplataforma de Google.
- Dart 3.0+: lenguaje de programación moderno y tipado.
- GetX 4.6.6: framework para gestión de estado y dependencias.

### 3.2 Base de datos
- SQLite: base de datos relacional embebida.
- `sqflite`: plugin Flutter para acceso a SQLite.
- `sqlite3_flutter_libs`: librerías nativas para Windows.

### 3.3 Seguridad
- Algoritmo SHA-256 para encriptación de contraseñas.
- Sistema de autenticación basado en sesiones.
- Autorización granular por roles y permisos.
- Validación de entrada de datos.

### 3.4 Generación de documentos
- `pdf` 3.10.7: librería para generación de documentos PDF.
- `excel` 2.1.0: librería para exportación a formato Excel.
- `intl` 0.20.2: internacionalización y formato de datos.

### 3.5 Interfaz de usuario
- Material Design 3: sistema de diseño moderno.
- Widgets personalizados para componentes específicos.
- Tema adaptable y consistente en toda la aplicación.

### 3.6 Hardware y periféricos
- `libserialport` 0.3.0+1: comunicación con balanzas electrónicas.
- Sistema de impresión para tickets y facturas.

## 4. Funciones técnicas principales

### 4.1 Procesamiento de transacciones
El sistema procesa transacciones de venta en tiempo real:
- Registro de productos en carrito de compras.
- Cálculo automático de subtotales por ítem.
- Cálculo automático de impuestos (IVA 19%).
- Cálculo de totales generales.
- Aplicación de descuentos y promociones.
- Procesamiento de múltiples métodos de pago.
- Generación de tickets de venta.
- Actualización inmediata de inventario.

### 4.2 Gestión de inventario
- Control completo de productos con códigos de barras.
- Gestión de productos por unidad y por peso.
- Control automático de stock con alertas de inventario bajo.
- Categorización de productos en grupos y categorías.
- Registro de movimientos de inventario (entradas, salidas, ajustes).
- Importación masiva desde archivos Excel/CSV.
- Valorización de inventario.

### 4.3 Gestión de clientes
- Base de datos completa de clientes.
- Validación de documentos de identidad (Cédula, NIT, RUT).
- Historial completo de compras por cliente.
- Búsqueda avanzada de clientes.
- Clasificación de clientes (Cuantías Menores / Cliente Registrado).

### 4.4 Facturación electrónica (módulo en desarrollo)
- Preparación de estructura para facturación electrónica según normativa DIAN.
- Validación de datos fiscales del cliente (NIT, RUT, direcciones).
- Cálculo automático de IVA según tarifas vigentes.
- Estados de facturación (borrador, simulado).
- Módulo en fase de pruebas y desarrollo, no autorizado directamente por DIAN.
- Simulación de generación de documentos electrónicos para pruebas.

### 4.5 Reportes y contabilidad
- Reportes de ventas por período (diario, semanal, mensual).
- Reportes de inventario con valorización.
- Reportes de rentabilidad y márgenes.
- Reportes de cuentas por cobrar y por pagar.
- Exportación a formato PDF para impresión.

### 4.6 Gestión de usuarios y seguridad
- Sistema de autenticación seguro con contraseñas encriptadas.
- Cinco roles predefinidos:
  - Admin: acceso total al sistema.
  - Cajero: acceso a módulos de ventas y clientes.
  - Gerente: acceso parcial al sistema, sin eliminar usuarios.
  - Supervisor: acceso parcial, sin editar usuarios ni eliminar productos.
  - Mantenimiento: acceso a configuración y mantenimiento.
- Permisos granulares por módulo y funcionalidad.
- Auditoría de actividades del sistema.
- Registro de logs de acceso y modificaciones.

### 4.7 Configuración del sistema
- Configuración de datos de la empresa.
- Configuración fiscal para cumplimiento DIAN.
- Configuración de impresoras y periféricos.
- Sistema de respaldo automático de datos.
- Personalización de textos en facturas.

## 5. Modelo de datos

### 5.1 Tablas principales
- **users:** almacena información de usuarios del sistema. Campos: `id`, `username`, `password` (encriptado SHA-256), `fullName`, `role`, `userCode`, `isActive`, `createdAt`, etc.
- **products:** catálogo completo de productos. Campos: `id`, `code`, `shortCode`, `name`, `price`, `cost`, `stock`, `category`, `unit`, `isWeighted`, `pricePerKg`, `weight`, `minWeight`, `maxWeight`, etc.
- **customers:** base de datos de clientes. Campos: `id`, `name`, `email`, `phone`, `address`, `documentNumber`, `documentType`, `pointsRate`, `accumulatedPoints`, `totalPurchases`, etc.
- **sales:** registro de ventas realizadas (items almacenados como JSON). Campos: `id`, `date`, `total`, `user`, `paymentMethod`, `items` (JSON), `discount`, `discountPercentage`, `isReturn`, `originalSaleId`, `returnedAmount`, etc.
- **groups:** grupos y categorías de productos. Campos: `id`, `name`, `description`, `color`, `icon`, `isActive`, `createdAt`, `updatedAt`.
- **inventory_movements:** movimientos de inventario. Campos: `id`, `productId`, `type`, `quantity`, `reason`, `description`, `date`, `userId`.
- **company_config:** configuración de la empresa. Campos: `id`, `company_name`, `address`, `phone`, `email`, `tax_id`, `nit_number`, `verification_digit`, `fiscal_responsibilities`, etc.
- **clients:** clientes para facturación electrónica (módulo en desarrollo). Campos: `id`, `documentType`, `documentNumber`, `businessName`, `email`, `phone`, `address`, `fiscalResponsibility`, `city`, `department`, `country`, etc.
- **suppliers:** base de datos de proveedores. Campos: `id`, `name`, `document`, `document_type`, `phone`, `email`, `address`, `city`, `department`, `country`, `tax_regime`, etc.
- **accounting_entries:** entradas contables. Campos: `id`, `type`, `amount`, `description`, `category`, `subcategory`, `date`, `user_id`, `cash_session_id`, `payment_method`, etc.
- **cash_sessions:** sesiones de caja registradora. Campos: `id`, `open_date`, `close_date`, `initial_amount`, `final_amount`, `total_income`, `total_expense`, `difference`, `status`, `user_id`, `closed_by_user_id`, etc.

### 5.2 Relaciones entre tablas
- `sales` almacena items como JSON (no existe tabla `sale_items` separada).
- `products` se relaciona con `groups` mediante `category` (no existe foreign key directa).
- `inventory_movements` → `products` (relación muchos a uno mediante `productId`).
- `inventory_movements` → `users` (relación muchos a uno mediante `userId`).
- `accounting_entries` → `users` (relación muchos a uno mediante `user_id`).
- `cash_sessions` → `users` (relación muchos a uno mediante `user_id`).
- `cash_sessions` → `users` (relación muchos a uno mediante `closed_by_user_id`).

## 6. Flujo de funcionamiento

### 6.1 Proceso de venta
1. Usuario inicia sesión con credenciales autenticadas.
2. Selecciona el módulo de Punto de Venta (POS).
3. Busca productos por nombre o código de barras.
4. Agrega productos al carrito de compras.
5. El sistema calcula automáticamente totales e impuestos.
6. Selecciona método de pago.
7. Procesa la venta.
8. El sistema actualiza automáticamente el inventario.
9. Genera ticket de venta y factura si aplica.
10. Registra la transacción en la base de datos.

### 6.2 Proceso de facturación electrónica (simulado)
1. Usuario genera factura desde el módulo POS o facturación.
2. Sistema valida datos fiscales del cliente (NIT, RUT, formato de documentos).
3. Calcula impuestos según normativa vigente.
4. Simula generación de documento electrónico (en desarrollo).
5. Almacena factura en estado simulado para pruebas.
6. El módulo está en fase de desarrollo y no está autorizado directamente por DIAN.

### 6.3 Proceso de gestión de inventario
1. Usuario accede al módulo de inventario.
2. Puede agregar nuevos productos o editar existentes.
3. Registra movimientos (entradas, salidas, ajustes).
4. Sistema actualiza niveles de stock automáticamente.
5. Genera alertas cuando el stock está bajo.
6. Permite importación masiva desde Excel.

## 7. Características de seguridad

### 7.1 Encriptación
- Todas las contraseñas se almacenan utilizando algoritmo SHA-256.
- Las contraseñas nunca se almacenan en texto plano.
- El hash de contraseñas garantiza seguridad ante accesos no autorizados.

### 7.2 Autenticación
- Sistema de login seguro con validación de credenciales.
- Sesiones de usuario controladas.
- Timeout automático de sesiones inactivas.

### 7.3 Autorización
- Sistema granular de permisos por módulo.
- Roles predefinidos con permisos específicos.
- Control de acceso a funcionalidades sensibles.

### 7.4 Validación de datos
- Validación de entrada en todos los formularios.
- Validación de formato de documentos fiscales (NIT, RUT, cédulas).
- Validación de estructura de datos según formatos requeridos.
- Prevención de inyección SQL mediante parámetros preparados.

### 7.5 Auditoría
- Registro de todas las operaciones importantes.
- Logs de acceso al sistema.
- Trazabilidad completa de modificaciones.

## 8. Plataformas soportadas

- Windows 10/11 (64-bit): plataforma principal de desarrollo y despliegue.

## 9. Requisitos del sistema

**Requisitos mínimos:**
- Procesador: Intel Core i3 o equivalente.
- RAM: 4 GB (8 GB recomendado).
- Disco duro: 2 GB de espacio libre.
- Sistema Operativo: Windows 10 (64-bit) o superior.
- Conexión a internet: necesaria para facturación electrónica (opcional).

## 10. Módulos del sistema

### 10.1 Módulo de punto de venta (POS)
Interfaz optimizada para procesamiento rápido de ventas:
- Búsqueda de productos por nombre o código de barras.
- Carrito de compras dinámico con edición de cantidades.
- Integración con balanzas electrónicas para productos pesables (en proceso).
- Cálculo automático de totales e impuestos.
- Múltiples métodos de pago.
- Impresión opcional de tickets.

### 10.2 Módulo de gestión de inventario
Control completo del inventario de productos:
- Gestión de productos (unidad y peso).
- Control de stock con alertas.
- Categorías y grupos de productos.
- Movimientos de inventario.
- Importación desde Excel.

### 10.3 Módulo de gestión de clientes
Administración de la base de datos de clientes:
- Registro completo de información de clientes.
- Validación de documentos.
- Historial de compras.
- Búsqueda avanzada.

### 10.4 Módulo de facturación electrónica (en desarrollo)
Preparación para facturación electrónica:
- Validación de datos fiscales del cliente (formato NIT, RUT).
- Estructura preparada para facturación electrónica.
- Cálculo de impuestos según normativa vigente.
- Módulo en fase de pruebas simulado, no autorizado directamente por DIAN.
- Gestión de estados de facturación en modo simulado.

### 10.5 Módulo de reportes
Generación de reportes profesionales:
- Reportes de ventas.
- Reportes de inventario.
- Reportes contables.
- Exportación a PDF.

### 10.6 Módulo de usuarios y permisos
Administración del sistema:
- Gestión de usuarios.
- Asignación de roles.
- Configuración de permisos.

### 10.7 Módulo de configuración (en proceso)
- Ajustes avanzados en desarrollo para personalización del sistema.

### 10.8 Módulo "Datos de empresa"
Módulo independiente accesible desde el dashboard que permite:
- Carga de datos básicos de la empresa (nombre, dirección, teléfono, email, sitio web, NIT/RUT).
- Configuración fiscal para facturación electrónica (tipo de documento, número de NIT y dígito de verificación, ciudad, departamento, país, régimen y responsabilidades fiscales).
- Configuración de textos para impresión (cabecera y pie en tickets/facturas).

## 11. Conclusiones

SmartSeller POS v1.0 es un sistema de punto de venta profesional desarrollado con tecnologías modernas que garantizan:

- **Seguridad:** encriptación SHA-256 y sistema robusto de permisos.
- **Confiabilidad:** base de datos local con respaldo automático.
- **Escalabilidad:** arquitectura modular fácil de extender.
- **Usabilidad:** interfaz intuitiva basada en Material Design 3.
- **Cumplimiento:** normativa DIAN para facturación electrónica (en proceso).
- **Rendimiento:** optimizado para operaciones rápidas y eficientes.

El sistema está diseñado para ser una solución completa y profesional para la gestión de puntos de venta en Colombia, cumpliendo con todos los estándares de calidad y seguridad requeridos para aplicaciones comerciales de producción.

## 12. Guía de instalación y configuración

### 12.1 Requisitos previos
- Flutter SDK 3.16.0 o superior (con Dart 3.0+), instalado en Windows.
- Visual Studio 2022 con el componente "Desktop development with C++" para compilar ejecutables de Windows.
- Git (opcional si se va a clonar el repositorio).
- Windows 10/11 de 64 bits con PowerShell y permisos de ejecución.
- Librerías nativas empaquetadas: `sqlite3.dll`, `sqlite3_flutter_libs_plugin.dll`, `flutter_windows.dll` (incluidas en el cliente).

### 12.2 Pasos de instalación para desarrollo
1. Clonar o descargar el repositorio `SmartSeller POS v1.0`.
2. Abrir PowerShell en la carpeta raíz y ejecutar `flutter pub get`.
3. Verificar la configuración con `flutter doctor -v`, asegurando que el target Windows esté habilitado.
4. Ejecutar en modo desarrollo con `flutter run -d windows`.
5. Para utilizar una base de datos preexistente, colocar el archivo `.db` (si aplica) en `SmartSellerPOS_Cliente_v3/data`.
6. Ajustar parámetros de pruebas de facturación en `lib/services/facturacion_service.dart` con credenciales simuladas.

### 12.3 Configuración opcional
- Definir constantes o variables de entorno en `lib/utils/constants.dart` para URLs y claves externas (modo simulado).
- Ajustar rutas de impresoras y balanzas en `lib/services/printing/` y `lib/services/peripherals/`.
- Configurar idioma y regionalización en `lib/main.dart` y utilidades de localización.

## 13. Estructura del proyecto

- `lib/main.dart`: punto de entrada, tema global y binding de GetX.
- `lib/controllers/`: controladores de estado por módulo (ventas, inventario, usuarios).
- `lib/models/`: modelos de datos y mapeos a SQLite.
- `lib/services/`: servicios transversales (autenticación, base de datos, reportes PDF/Excel, periféricos).
- `lib/screens/`: pantallas principales para escritorio (login, dashboard, POS, inventario, clientes, reportes, configuración).
- `lib/modules/`: componentes compuestos y vistas especializadas por módulo funcional.
- `lib/widgets/`: widgets reutilizables para escritorio (tablas, diálogos, botones).
- `lib/middleware/`: protección de rutas y validaciones de acceso.
- `lib/utils/`: constantes, helpers, formateadores y utilidades generales.
- `assets/images/`: recursos gráficos (logos, íconos).
- `test/`: pruebas automatizadas iniciales (unitarias y widgets).
- `SmartSellerPOS_Cliente_v3/`: distribución del ejecutable y dependencias para instalación.

## 14. Despliegue y distribución (escritorio)

### 14.1 Generación del ejecutable de Windows
1. Ejecutar `flutter build windows`.
2. Localizar la salida en `build/windows/x64/runner/Release`.
3. Copiar el ejecutable `smart_seller.exe` y las librerías nativas (`flutter_windows.dll`, `sqlite3.dll`, `sqlite3_flutter_libs_plugin.dll`) a la carpeta de distribución.
4. Incluir la carpeta `data` con la base de datos y archivos de configuración necesarios.

### 14.2 Paquetización
- Utilizar la estructura provista en `SmartSellerPOS_Cliente_v3`.
- Ejecutar los scripts `INSTALAR.bat` e `INSTALAR_DEPENDENCIAS.bat` para preparar la instalación en el equipo del cliente.
- Incluir los documentos `INSTRUCCIONES.md` y `SOLUCION_PROBLEMAS_EJECUTABLE.md` dentro del paquete final.

### 14.3 Actualizaciones
- Sustituir `smart_seller.exe` y librerías actualizadas en la carpeta de distribución.
- Mantener scripts de migración en `lib/services/database/migrations/` para actualizar la base SQLite cuando sea necesario.

## 15. Pruebas y control de calidad

### 15.1 Pruebas automatizadas
- Ejecución de `flutter test` para validar pruebas unitarias y de widgets (modelos, servicios y controladores).
- Plan de expansión para cubrir flujos críticos del POS e inventario en entorno de escritorio.

### 15.2 Pruebas manuales
- Casos definidos en `TESTING_PLAN.md`.
- Escenarios críticos: ventas con múltiples métodos de pago, devoluciones, alertas de stock, generación de reportes, conexión con periféricos.
- Pruebas de impresión siguiendo `TEST_IMPRESORA.md` y `PRUEBA_IMPRESION.md`.

### 15.3 Seguimiento de calidad
- Registrar incidencias y correcciones en `CORRECCIONES_APLICADAS.txt`.
- Mantener histórico de ajustes en `MEJORAS_SEGURIDAD_IMPLEMENTADAS.md` y documentos asociados.

## 16. Mantenimiento y roadmap

### 16.1 Mantenimiento programado
- Revisar dependencias trimestralmente (`flutter pub upgrade`).
- Realizar copias de seguridad periódicas de la carpeta `data` en la distribución.
- Verificar logs de auditoría y accesos para detectar actividades anómalas.
- Validar la generación de reportes PDF/Excel tras cada actualización.

### 16.2 Evolución planificada
- Completar la integración oficial con servicios DIAN para facturación electrónica.
- Implementar migraciones automáticas de esquema en SQLite.
- Añadir soporte para autenticación multifactor en escritorio.
- Mejorar la interfaz de reportes con gráficos y filtros avanzados.

## 17. Anexos y referencias

- Normativa DIAN (factura electrónica): https://www.dian.gov.co
- Documentación Flutter Desktop: https://docs.flutter.dev/desktop
- Guía Material Design 3: https://m3.material.io
- Documentación interna relevante: `POS_OPTIMIZADO_GUIA.md`, `SISTEMA_AUTORIZACION_PROFESIONAL.md`, `MODULO_FACTURACION_ELECTRONICA.md`, `SOLUCION_PROBLEMAS_EJECUTABLE.md`.
- Glosario sugerido: DIAN, POS, NIT, RUT, IVA, Ticket, Sesión de Caja, SQLite.

## 18. Historial de versiones

- **v1.0 (septiembre 2025):** primera versión estable de escritorio con módulos de POS, inventario, clientes, reportes y facturación electrónica simulada.
- **Próxima versión (planificada):** integración DIAN productiva, módulo de configuración completo y nuevos reportes contables con funcionalidades avanzadas.
