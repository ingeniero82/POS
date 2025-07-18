# 🔧 Diagnóstico de Impresora Citizen TZ30-M01

## 🚨 **Pasos de Diagnóstico**

### **Paso 1: Verificar Conexión Física**
1. ✅ **Conectar impresora**: USB o puerto serie
2. ✅ **Encender impresora**: LED debe estar encendido
3. ✅ **Instalar drivers**: Si es necesario (descarga desde Citizen)

### **Paso 2: Verificar en Windows**
```
Panel de Control > Dispositivos e Impresoras
```
- ¿Aparece "Citizen TZ30" o similar?
- ¿Está marcada como "Lista"?
- **Clic derecho > Imprimir página de prueba**

### **Paso 3: Ejecutar Diagnóstico en Aplicación**

#### 📱 **Logs que debes ver:**
Al ejecutar `flutter run -d windows`, en la consola debe aparecer:

```
🖨️ Inicializando PrintService...
🔍 Iniciando detección de impresora...
📋 Impresoras encontradas en el sistema:
   - Microsoft Print to PDF
   - Citizen TZ30-M01 (✅ Citizen)    ← ¡ESTO ES LO IMPORTANTE!
📱 Intentando conexión USB...
✅ Impresora Citizen conectada por USB
✅ PrintService inicializado correctamente
```

#### ❌ **Si no aparece:**
```
📋 Impresoras encontradas en el sistema:
   - Microsoft Print to PDF
   - Fax
❌ No se pudo detectar la impresora
⚠️ Impresora no detectada - Funcionará en modo simulación
```

### **Paso 4: Comandos de Prueba Manual**

#### **En la consola de Flutter Debug:**
```dart
// Verificar si funciona en modo simulación
await PrintService.instance.listPrinters();
```

### **Paso 5: Verificación por Puerto Serie**

Si USB no funciona, probar puerto serie:

1. **Verificar puerto COM**: 
   - Administrador de dispositivos
   - Puertos (COM y LPT)
   - ¿Está listado "Citizen TZ30"?

2. **Anotar puerto**: Ej: COM3, COM4, etc.

## 🔍 **Estados Posibles**

### ✅ **Funcionando Correctamente**
```
🔌 Puerto: USB_Citizen TZ30-M01
🔍 Estado: Conectada
📋 Impresoras: 1 Citizen detectada
```

### ⚠️ **Modo Simulación**
```
🔌 Puerto: SIMULATION
🔍 Estado: Conectada (simulación)
📋 Impresoras: 0 Citizen detectadas
```

### ❌ **No Funciona**
```
🔌 Puerto: (vacío)
🔍 Estado: No conectada
📋 Impresoras: Error al listar
```

## 🛠️ **Soluciones por Problema**

### **Problema: No aparece en "Impresoras encontradas"**
**Solución:**
1. Reinstalar drivers de Citizen
2. Conectar por USB diferente
3. Verificar que Windows reconoce el dispositivo

### **Problema: Aparece pero no conecta**
**Solución:**
1. Verificar permisos de la aplicación
2. Cerrar otros programas que usen la impresora
3. Reiniciar impresora

### **Problema: Conecta pero no imprime**
**Solución:**
1. Verificar papel en la impresora
2. Comprobar comandos ESC/POS
3. Probar impresión desde Windows primero

### **Problema: Error de compilación C++**
**Solución:**
1. `flutter clean`
2. Verificar Visual Studio está instalado
3. Reinstalar Flutter

## 📊 **Información del Sistema**

### **Tu Configuración Actual:**
- **OS**: Windows 10/11
- **Impresora**: Citizen TZ30-M01
- **Conexión**: USB/Serie
- **Flutter**: Versión actual

### **Logs Importantes a Compartir:**
1. Lista completa de impresoras encontradas
2. Mensajes de error específicos
3. Estado de conexión USB/Serie

---

## 🎯 **Próximos Pasos**

1. **Ejecutar aplicación** con `flutter run -d windows`
2. **Copiar logs** de la consola
3. **Hacer una venta de prueba**
4. **Verificar qué mensajes aparecen**

**¡Con esta información podremos diagnosticar exactamente dónde está el problema!** 🔧 