# 🔧 **ROL DE MANTENIMIENTO - SmartSeller POS**

## 📋 **DESCRIPCIÓN GENERAL**

El **Rol de Mantenimiento** es un nuevo nivel de acceso en SmartSeller POS diseñado específicamente para usuarios que necesitan configurar y mantener los datos críticos de la empresa, especialmente aquellos que afectan la impresión y facturación electrónica.

## 🎯 **OBJETIVO PRINCIPAL**

**Proteger datos críticos** de la empresa que solo deben ser modificados por personal autorizado, evitando cambios accidentales que puedan afectar:
- ✅ **Impresión de facturas** (encabezado, datos de empresa)
- ✅ **Configuración fiscal** (NIT, DV, régimen fiscal)
- ✅ **Datos de facturación electrónica** (DIAN, software ID/PIN)
- ✅ **Configuración del sistema** (rutas, respaldos)

## 🔐 **PERMISOS EXCLUSIVOS**

### **✅ ACCESO PERMITIDO:**
- `accessCompanyConfig` - Acceder a configuración de empresa
- `modifyCompanyConfig` - Modificar configuración de empresa  
- `accessSystemConfig` - Acceder a configuración del sistema
- `modifySystemConfig` - Modificar configuración del sistema
- `accessDashboard` - Ver estado del sistema

### **❌ ACCESO DENEGADO:**
- Gestión de usuarios
- Gestión de productos
- Punto de venta (POS)
- Inventario
- Reportes
- Gestión de clientes
- Cualquier otra funcionalidad operativa

## 👤 **USUARIO POR DEFECTO**

### **Credenciales de Acceso:**
```
Usuario: maintenance
Contraseña: maint123
Rol: maintenance
Código: MAINT-001
```

### **⚠️ IMPORTANTE:**
- **Cambiar la contraseña** después del primer acceso
- **No compartir** estas credenciales con personal operativo
- **Usar solo** para tareas de mantenimiento del sistema

## 🚀 **CONFIGURACIÓN INICIAL**

### **1. Crear Usuario de Mantenimiento:**
```dart
// Importar el servicio
import '../services/maintenance_user_setup.dart';

// Crear usuario por defecto
await MaintenanceUserSetup.createDefaultMaintenanceUser();
```

### **2. Verificar Creación:**
```dart
// Verificar si existe
bool hasMaintenanceUser = await MaintenanceUserSetup.hasMaintenanceUser();

// Obtener información
User? maintenanceUser = await MaintenanceUserSetup.getMaintenanceUser();
```

### **3. Cambiar Contraseña:**
```dart
// Cambiar a contraseña segura
await MaintenanceUserSetup.changeMaintenancePassword('nueva_contraseña_segura');
```

## 🛡️ **PROTECCIÓN IMPLEMENTADA**

### **1. Pantalla de Configuración de Empresa:**
- ✅ **Verificación de permisos** antes de mostrar contenido
- ✅ **Acceso denegado** para usuarios sin rol de mantenimiento
- ✅ **Indicador visual** del rol de mantenimiento activo
- ✅ **Mensaje claro** explicando por qué se bloquea el acceso

### **2. Sistema de Permisos:**
- ✅ **Nuevo rol** `maintenance` agregado al enum `UserRole`
- ✅ **Permisos específicos** para configuración del sistema
- ✅ **Validación** en todas las pantallas críticas
- ✅ **Integración** con el sistema de permisos existente

### **3. Interfaz de Usuario:**
- ✅ **Dropdown de roles** actualizado en formularios
- ✅ **Colores distintivos** para el rol de mantenimiento
- ✅ **Descripciones** claras en todas las pantallas
- ✅ **Filtros** funcionando correctamente

## 📱 **PANTALLAS PROTEGIDAS**

### **🔒 Configuración de Empresa:**
- Datos básicos de la empresa
- Encabezado y pie de página para impresión
- Información fiscal (NIT, DV, régimen)
- Responsabilidades fiscales

### **🔒 Configuración del Sistema:**
- Resolución DIAN
- Software ID y PIN
- Ambiente (pruebas/producción)
- Rutas de salida (XML/PDF)

### **🔒 Otras Configuraciones:**
- Respaldo y restauración
- Auditoría del sistema
- Configuración de impresoras

## 🚨 **SEGURIDAD Y AUDITORÍA**

### **1. Control de Acceso:**
- ✅ **Verificación de permisos** en cada pantalla
- ✅ **Bloqueo automático** para usuarios no autorizados
- ✅ **Mensajes claros** explicando la restricción

### **2. Auditoría:**
- ✅ **Log de accesos** a configuraciones críticas
- ✅ **Registro de cambios** en datos de empresa
- ✅ **Traza completa** de modificaciones

### **3. Respaldo:**
- ✅ **Backup automático** antes de cambios críticos
- ✅ **Restauración** en caso de problemas
- ✅ **Versionado** de configuraciones

## 🔄 **FLUJO DE TRABAJO RECOMENDADO**

### **1. Acceso Inicial:**
```
1. Login con usuario: maintenance
2. Cambiar contraseña por defecto
3. Verificar permisos activos
4. Revisar configuración actual
```

### **2. Modificación de Datos:**
```
1. Acceder a configuración de empresa
2. Realizar cambios necesarios
3. Guardar configuración
4. Verificar cambios aplicados
5. Generar respaldo si es necesario
```

### **3. Mantenimiento Regular:**
```
1. Revisar estado del sistema
2. Actualizar datos fiscales si cambian
3. Verificar respaldos automáticos
4. Revisar logs de auditoría
```

## ⚠️ **CONSIDERACIONES IMPORTANTES**

### **1. Limitaciones del Rol:**
- **No puede** gestionar usuarios
- **No puede** acceder al POS
- **No puede** modificar inventario
- **No puede** generar reportes

### **2. Responsabilidades:**
- **Mantener** datos de empresa actualizados
- **Verificar** configuración fiscal
- **Supervisar** respaldos del sistema
- **Documentar** cambios realizados

### **3. Seguridad:**
- **Usar contraseñas** fuertes
- **No compartir** credenciales
- **Cerrar sesión** después de cada uso
- **Reportar** cualquier actividad sospechosa

## 🆘 **SOLUCIÓN DE PROBLEMAS**

### **Error: "Acceso Denegado"**
```
Causa: Usuario no tiene rol de mantenimiento
Solución: Verificar rol del usuario en gestión de usuarios
```

### **Error: "No se puede crear usuario de mantenimiento"**
```
Causa: Problema en base de datos o permisos
Solución: Verificar integridad de la base de datos
```

### **Error: "Permisos no encontrados"**
```
Causa: Sistema de permisos no inicializado
Solución: Reiniciar aplicación y verificar servicios
```

## 📞 **CONTACTO Y SOPORTE**

### **Para Problemas Técnicos:**
- Revisar logs de la aplicación
- Verificar estado de la base de datos
- Contactar al equipo de desarrollo

### **Para Cambios de Configuración:**
- Documentar cambios realizados
- Generar respaldo antes de modificar
- Probar en ambiente de desarrollo primero

---

## 🎉 **CONCLUSIÓN**

El **Rol de Mantenimiento** proporciona una capa adicional de seguridad para los datos críticos de SmartSeller POS, asegurando que solo personal autorizado pueda modificar configuraciones que afectan la operación del sistema.

**¡La implementación está completa y lista para usar!** 🚀
