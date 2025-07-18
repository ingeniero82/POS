# 🧾 Módulo de Facturación Electrónica DIAN

## 📋 Descripción
El módulo de **Facturación Electrónica DIAN** es una funcionalidad completa para generar facturas electrónicas según los estándares de la DIAN (Dirección de Impuestos y Aduanas Nacionales) de Colombia.

## 🚀 Características Principales

### **Acceso Rápido**
- **F2**: Abre el módulo de facturación electrónica desde cualquier pantalla
- **Pantalla Completa**: Se abre como un módulo independiente, no como diálogo
- **Navegación por Pestañas**: Organización clara de la información

### **Funcionalidades**

#### **📄 Datos de Factura**
- Número de factura con formato personalizable
- Fecha de emisión y vencimiento con selector de calendario
- Medio de pago (Efectivo, Tarjeta, Transferencia, etc.)
- Observaciones adicionales
- Validación de campos obligatorios

#### **👤 Información del Cliente**
- Tipo de cliente (Cuantías Menores / Cliente Registrado)
- NIT/RUT del cliente
- Nombre/Razón Social
- Dirección completa
- Teléfono y Email
- Búsqueda de clientes existentes

#### **🛒 Productos de la Factura**
- Lista de productos con cantidades y precios
- Cálculo automático de subtotales
- IVA del 19% calculado automáticamente
- Total general de la factura
- Eliminación de productos individuales

### **Botones de Acción**
- **Guardar Borrador**: Guarda la factura como borrador
- **Enviar a DIAN**: Envía la factura a la DIAN para autorización

## 🎯 Flujo de Trabajo

### **Paso 1: Acceso al Módulo**
1. Presiona **F2** desde cualquier pantalla del sistema
2. Se abre la pantalla completa de facturación electrónica
3. El sistema inicia en la pestaña "Datos Factura"

### **Paso 2: Configurar Datos de Factura**
1. Ingresa el número de factura (ej: FE-001)
2. Selecciona fecha de emisión y vencimiento
3. Elige el medio de pago
4. Agrega observaciones si es necesario

### **Paso 3: Configurar Cliente**
1. Cambia a la pestaña "Cliente"
2. Selecciona tipo de cliente:
   - **Cuantías Menores**: Para ventas menores a $35,000
   - **Cliente Registrado**: Para clientes con NIT
3. Completa los datos del cliente
4. Usa "Buscar Cliente" para cargar datos existentes

### **Paso 4: Agregar Productos**
1. Cambia a la pestaña "Productos"
2. Haz clic en "Agregar Producto"
3. Selecciona productos de la lista
4. Especifica cantidades
5. Los totales se calculan automáticamente

### **Paso 5: Finalizar Factura**
1. Revisa todos los datos
2. Presiona "Guardar Borrador" o "Enviar a DIAN"
3. El sistema valida todos los campos
4. Se procesa la factura según la acción seleccionada

## 🔧 Validaciones del Sistema

### **Validaciones de Factura**
- ✅ Número de factura obligatorio
- ✅ Fecha de emisión obligatoria
- ✅ Fecha de vencimiento obligatoria
- ✅ Medio de pago obligatorio

### **Validaciones de Cliente**
- ✅ Para "Cuantías Menores": No requiere validación adicional
- ✅ Para "Cliente Registrado": NIT y nombre obligatorios

### **Validaciones de Productos**
- ✅ Al menos un producto en la factura
- ✅ Cantidades mayores a cero
- ✅ Precios válidos

## 📊 Cálculos Automáticos

### **Subtotal**
```
Subtotal = Σ(Producto.precio × Producto.cantidad)
```

### **IVA (19%)**
```
IVA = Subtotal × 0.19
```

### **Total**
```
Total = Subtotal + IVA
```

## 🎨 Interfaz de Usuario

### **Colores del Sistema**
- **🔵 Azul Principal**: `#1976D2` - Headers y elementos principales
- **🟢 Verde**: `#4CAF50` - Botón "Enviar a DIAN"
- **🔴 Rojo**: `#F44336` - Botones de eliminar
- **⚫ Gris**: `#424242` - Textos principales

### **Componentes UI**
- **Pestañas**: Navegación clara entre secciones
- **Formularios**: Campos con validación visual
- **Tablas**: Lista de productos con encabezados
- **Botones**: Estados de carga y feedback visual

## 🔐 Seguridad y Permisos

### **Permisos Requeridos**
- `Permission.accessElectronicInvoicing`: Acceso al módulo
- `Permission.createInvoices`: Crear facturas
- `Permission.sendToDIAN`: Enviar a DIAN

### **Validaciones de Seguridad**
- Usuario autenticado obligatorio
- Permisos verificados antes de cada acción
- Log de todas las operaciones

## 🚨 Manejo de Errores

### **Errores de Validación**
- Campos obligatorios no completados
- Datos de cliente incompletos
- Sin productos en la factura

### **Errores de Conexión**
- Problemas de red al enviar a DIAN
- Errores de base de datos
- Timeouts de conexión

### **Feedback al Usuario**
- Mensajes de error claros y específicos
- Indicadores de carga durante operaciones
- Confirmaciones de éxito

## 📱 Compatibilidad

### **Dispositivos Soportados**
- ✅ Windows (Desktop)
- ✅ Android (Tablets POS)
- ✅ Web (Navegadores modernos)

### **Resoluciones Optimizadas**
- **Desktop**: 1920x1080 y superiores
- **Tablet**: 1024x768 y superiores
- **Responsive**: Adaptable a diferentes tamaños

## 🔄 Integración con el Sistema

### **Base de Datos**
- Almacenamiento de facturas en SQLite
- Historial de borradores
- Registro de envíos a DIAN

### **Servicios Conectados**
- `ClientService`: Búsqueda y gestión de clientes
- `ProductService`: Catálogo de productos
- `AuthService`: Autenticación y permisos

### **Navegación**
- Integrado con el sistema de rutas de GetX
- Middleware de autenticación
- Navegación fluida entre módulos

## 🚀 Próximas Mejoras

### **Funcionalidades Planificadas**
- [ ] Integración real con DIAN
- [ ] Generación de PDF de facturas
- [ ] Envío por email automático
- [ ] Historial de facturas enviadas
- [ ] Notas crédito y débito
- [ ] Facturas de contingencia

### **Mejoras de UX**
- [ ] Búsqueda avanzada de productos
- [ ] Autocompletado de clientes
- [ ] Plantillas de facturación
- [ ] Atajos de teclado adicionales

## 📞 Soporte

### **Documentación Adicional**
- Ver `BALANZA_INTEGRATION.md` para integración con básculas
- Ver `SISTEMA_AUTORIZACION_PROFESIONAL.md` para permisos
- Ver `POS_OPTIMIZADO_GUIA.md` para optimización del POS

### **Contacto**
- Para problemas técnicos: Revisar logs del sistema
- Para funcionalidades: Consultar documentación de DIAN
- Para soporte: Contactar al equipo de desarrollo

---

**Versión**: 1.0.0  
**Última actualización**: Diciembre 2024  
**Compatibilidad**: Flutter 3.0+  
**DIAN**: Estándares 2024 