# Informe detallado – POS Smart Seller (v1.0 DNPA)

**Proyecto:** Smart Seller POS  
**Versión:** 1.0 DNPA  
**Tecnología:** Flutter (Dart), GetX  
**Plataformas:** Windows (principal), soporte multi-plataforma en código  

---

## 1. Funcionalidades principales

### ¿Qué puede hacer el POS?

| Módulo | Funcionalidad |
|--------|----------------|
| **Ventas** | Punto de venta con carrito, escaneo por código de barras o búsqueda manual, múltiples métodos de pago, descuentos, devoluciones, impresión de recibos, apertura de cajón. |
| **Inventario** | Productos con código, código corto, precio, costo, stock, mínimo de stock, categoría, unidad; productos por peso (balanza); grupos/categorías; movimientos de inventario (entradas/salidas); alertas de stock bajo. |
| **Clientes** | CRUD de clientes (nombre, email, teléfono, dirección, documento); puntos de fidelidad (tasa, acumulados, última compra, total compras). |
| **Reportes** | Reportes de ventas, inventario, clientes, proveedores; reportes contables (estado de resultados, flujo de caja, sesiones de caja, auditoría); exportación a PDF/Excel. |
| **Contabilidad** | Entradas contables, movimientos de caja, sesiones de caja (apertura/cierre), métodos de pago, categorías de transacciones; registro de ingresos por venta, egresos, pagos a proveedores, gastos operativos, devoluciones a proveedores. |
| **Cuentas por cobrar y pagar** | Cuentas por cobrar (clientes), cuentas por pagar (proveedores), pagos con método y referencia, fechas de vencimiento, estados. |
| **Proveedores** | CRUD de proveedores, pagos a proveedores, integración con entradas contables. |
| **Configuración** | Configuración de empresa (nombre, dirección, teléfono, email, NIT, encabezado/pie de factura, datos fiscales para facturación electrónica); configuración del sistema. |
| **Facturación electrónica** | Módulo de facturación electrónica: generación de documentos, estado de facturas, cola de facturas pendientes, validación pre-emisión, configuración del sistema (DIAN/Colombia). |

### ¿Maneja múltiples usuarios/cajeros?

**Sí.** Hay usuarios con roles; cada venta se asocia al usuario que la registra. Sesiones de caja por usuario (apertura/cierre).

### ¿Tiene roles/permisos?

**Sí.** Roles definidos:

| Rol | Descripción |
|-----|-------------|
| **admin** | Acceso total (usuarios, productos, POS, inventario, reportes, configuración, clientes, etc.). |
| **manager** | Casi todo; no puede eliminar usuarios; puede modificar carrito (cantidad, precio, quitar ítems). |
| **supervisor** | POS, ventas, inventario, reportes, clientes; puede modificar precio/peso con autorización; reimprimir facturas; no eliminar usuarios/productos. |
| **cashier** | POS, procesar ventas, ver historial, inventario (solo ver), clientes; cambio de cantidad con autorización; sin modificar precio ni reimprimir sin autorización. |
| **maintenance** | Solo configuración de empresa y del sistema (mantenimiento). |

Permisos granulares (ver/crear/editar/eliminar por módulo, acceso POS, modificar precio, peso manual, descuentos, reimprimir, etc.). Autorización por código de usuario o código de barras para acciones sensibles (descuento, cambio de precio, peso manual, abrir cajón).

### ¿Facturación electrónica?

**Sí.** Módulo dedicado con:

- Pantallas: Facturación electrónica, Estado de facturas, Cola de pendientes, Configuración del sistema.
- Servicios: generación de documentos, estado de facturas, cola pendiente, validación pre-emisión, auditoría, respaldo, configuración (orientado a DIAN/Colombia).

---

## 2. Hardware que usa

| Dispositivo | Uso en el sistema |
|-------------|-------------------|
| **Impresora térmica** | **Citizen TZ30-M01.** Comandos ESC/POS (80 mm), papel 48 caracteres de ancho. Conexión USB y puerto serie; en Windows puede funcionar en modo simulación si no hay driver/plugin. |
| **Lector de código de barras** | Soporte en POS: campo de escaneo (simula teclado); modo “Escanear código de barras” con foco automático. No hay integración con hardware específico de escáner en el código. |
| **Cajón de dinero** | Comandos ESC/POS para cajón 1 y 2 (`ESC p 0` / `ESC p 1`). Se abre automáticamente al imprimir recibo (opcional) y con botón “Cajón (F5)”; requiere permiso (supervisor/gerente/admin). |
| **Balanza** | Productos con `isWeighted`, `weight`, `minWeight`, `maxWeight`, `pricePerKg`. Servicio previsto para **Aclas OS2X** (USB, 9600 bps, comando `W\r\n`); en el código hay stub/TODO (scale_service_real.dart), no hay integración real de lectura de peso en tiempo real. |
| **Pantalla para cliente** | No hay módulo ni referencia en código a segunda pantalla o display para cliente. |

---

## 3. Base de datos

### ¿Qué base de datos usas?

**SQLite**, vía `sqflite` y `sqflite_common_ffi` (escritorio Windows). Un solo archivo: `smart_seller.db`, ubicado en la carpeta de documentos del usuario (ej. `C:\Users\<usuario>\Documents\smart_seller.db`).

### Esquema principal de tablas

- **users** – id, username, password, fullName, role, createdAt, isActive, userCode  
- **groups** – id, name, description, color, icon, createdAt, updatedAt, isActive  
- **products** – id, code, shortCode, name, description, price, cost, stock, minStock, category, unit, createdAt, updatedAt, isActive, imageUrl, isWeighted, pricePerKg, weight, minWeight, maxWeight  
- **inventory_movements** – id, productId, type, quantity, reason, description, date, userId  
- **sales** – id, date, total, user, paymentMethod, items (JSON), discount, discountPercentage, isReturn, originalSaleId, returnedAmount  
- **customers** – id, name, email, phone, address, documentNumber, documentType, createdAt, updatedAt, isActive, pointsRate, accumulatedPoints, lastPurchase, totalPurchases  
- **company_config** – id, company_name, address, phone, email, website, tax_id, header_text, footer_text, document_type, nit_number, verification_digit, city, department, country, fiscal_regime, fiscal_responsibilities, created_at, updated_at  
- **clients** – (facturación electrónica DIAN) documentType, documentNumber, businessName, email, phone, address, fiscalResponsibility, etc.  
- **suppliers** – proveedores  
- **supplier_payments** – pagos a proveedores  
- **accounting_entries** – entradas contables (subcategory, cash_session_id, document_number, reference, related_entity, payment_method, etc.)  
- **cash_movements** – movimientos de caja  
- **cash_sessions** – sesiones de caja (apertura/cierre)  
- **payment_methods** – métodos de pago  
- **transaction_categories** – categorías de transacciones  
- **accounts_receivable** – cuentas por cobrar (customer_id, total_amount, paid_amount, pending_amount, invoice_number, due_date, status, etc.)  
- **accounts_payable** – cuentas por pagar (supplier_id, total_amount, paid_amount, pending_amount, etc.)  
- **receivable_payments** – pagos de cuentas por cobrar  
- **payable_payments** – pagos de cuentas por pagar  

### ¿Puedes exportar la estructura de la BD?

Sí. La estructura se crea y migra en código en `lib/services/sqlite_database_service.dart` (métodos `_onCreate`, `_onUpgrade` y migraciones). Para exportar solo estructura puedes: (1) crear una BD vacía con la app y luego en SQLite ejecutar `.schema`, o (2) extraer todos los `CREATE TABLE` de ese archivo y armarlos en un solo script SQL.

---

## 4. Pantallas principales

Rutas definidas en la app (GetX):

| Ruta | Pantalla |
|------|----------|
| `/login` | Login (usuario/contraseña). |
| `/dashboard` | Dashboard con menú lateral (Dashboard, Punto de venta, Inventario, Clientes, Proveedores, Cuentas por cobrar, Reportes, Configuración, Usuarios, Permisos, Códigos de autorización, etc.). |
| `/pos` | Punto de venta (carrito, escaneo/búsqueda, cantidades, total, métodos de pago, impresión, cajón). |
| `/productos` | Productos (listado, crear/editar, grupos). |
| `/usuarios` | Usuarios (listado, crear/editar, roles, códigos). |
| `/clientes` | Clientes (listado, crear/editar). |
| `/reportes` | Reportes (ventas, inventario, etc.). |
| `/configuracion-empresa` | Configuración de empresa. |
| `/grupos` | Grupos de productos. |
| `/proveedores` | Proveedores. |
| `/cuentas-cobrar-pagar` | Cuentas por cobrar y por pagar. |
| `/reportes-contables` | Reportes contables (estado de resultados, flujo de caja, sesiones, auditoría). |
| `/facturacion-electronica` | Facturación electrónica. |
| `/electronic-invoicing/system-config` | Configuración del sistema de facturación electrónica. |
| `/electronic-invoicing/status` | Estado de facturas. |
| `/electronic-invoicing/queue` | Cola de facturas pendientes. |
| `/debug` | Pantalla de depuración. |

**Capturas de pantalla:** El proyecto no incluye capturas en el repositorio. Se pueden generar ejecutando la app en Windows y capturando cada pantalla.

---

## 5. Lógica de negocio importante

### ¿Cómo calcula impuestos?

No hay cálculo explícito de IVA ni de otros impuestos en el flujo de venta. La tabla `sales` tiene `total`, `discount`, `discountPercentage`; `company_config` y proveedores tienen campos fiscales (tax_id, fiscal_regime, etc.) para datos de facturación, no para cálculo de impuestos en el POS.

### ¿Maneja descuentos?

**Sí.** En ventas: descuento global por monto (`discount`) y por porcentaje (`discountPercentage`). En ítems de venta también hay `discount` y `discountPercentage`. Aplicar descuento en POS puede requerir autorización (supervisor/gerente/admin según permisos).

### ¿Control de stock en tiempo real?

**Sí.** Al procesar una venta se descuenta el stock de los productos. Hay movimientos de inventario (entradas/salidas) y alertas de stock mínimo. Productos inactivos no se listan para venta.

### ¿Múltiples métodos de pago?

**Sí.** En venta se elige `paymentMethod` (ej. Efectivo, Tarjeta, Crédito, Transferencia, PSE, Nequi, Daviplata, etc.). En `print_service` se definen métodos que requieren duplicado de recibo. Métodos de pago también se usan en contabilidad y en pagos de cuentas por cobrar/pagar.

### ¿Crédito a clientes?

**Sí.** Módulo de cuentas por cobrar: facturas a clientes con `total_amount`, `paid_amount`, `pending_amount`, `due_date`, `status`; pagos con `payment_method` y `reference`. Integración con facturación electrónica y reportes contables.

---

## Resumen técnico

- **Frontend:** Flutter (Dart), GetX (estado y rutas).  
- **Base de datos:** SQLite (archivo local).  
- **Impresión:** Citizen TZ30-M01, ESC/POS, cajón por comando.  
- **Balanza:** Preparado para Aclas OS2X (no implementado en tiempo real).  
- **Código de barras:** Entrada por teclado/escáner en campo de búsqueda en POS.  
- **Facturación electrónica:** Módulo completo (generación, estado, cola, configuración).  
- **Seguridad:** Contraseñas con hash SHA-256, roles y permisos por pantalla y acción, autorización por código/barras para acciones sensibles.
