# 🔧 Guía Completa: Comunicación con Balanza Aclas OS2X

## ✅ **Estado Actual del Sistema**

### **Problema Resuelto**
- ❌ **Antes**: Error `serialport.dl1` no encontrado
- ✅ **Ahora**: Comunicación usando PowerShell (más confiable en Windows)

### **Arquitectura Mejorada**
```
lib/services/
├── scale_service.dart          # Servicio principal
├── aclas_os2x_service.dart    # Servicio específico Aclas OS2X
└── scale_service_real.dart     # Implementación real (backup)
```

## 🚀 **Cómo Funciona Ahora**

### **1. Inicialización Automática**
```dart
// Al iniciar la aplicación
ScaleService().initialize()
    ↓
AclasOS2XService().connect()
    ↓
PowerShell → COM3 → Balanza Aclas OS2X
```

### **2. Flujo de Comunicación**
```
Aplicación Flutter
    ↓
PowerShell Script
    ↓
Puerto COM3 (9600 bps)
    ↓
Balanza Aclas OS2X
    ↓
Respuesta con peso
    ↓
Parseo y actualización UI
```

## 🔧 **Configuración de la Balanza**

### **Requisitos de Hardware**
- ✅ Balanza Aclas OS2X conectada por USB
- ✅ Cable USB en buen estado
- ✅ Drivers de Windows instalados
- ✅ Puerto COM reconocido (típicamente COM3)

### **Configuración de Puerto**
```powershell
# Configuración estándar para Aclas OS2X
Puerto: COM3
Baud Rate: 9600
Data Bits: 8
Parity: None
Stop Bits: 1
Flow Control: None
```

## 📋 **Comandos de la Balanza**

### **Comandos Enviados**
```dart
'W\r\n'  // Solicitar peso
'T\r\n'  // Tarar (poner en cero)
```

### **Respuestas Esperadas**
```
"ST,GS,   1.234kg"  // Peso estable
"ST,NET,  0.500kg"  // Peso neto
"US,GS,   0.000kg"  // Peso inestable
"S 00.000kga"       // Patrón específico de tu balanza
```

## 🛠️ **Solución de Problemas**

### **Problema 1: No se detecta la balanza**
**Síntomas:**
```
❌ Error buscando balanza: Invalid argument(s): Failed to load dynamic library 'serialport.dl1'
```

**Solución:**
1. ✅ **Ya implementado**: Usar PowerShell en lugar de libserialport
2. Verificar conexión USB
3. Revisar Administrador de dispositivos
4. Instalar drivers si es necesario

### **Problema 2: Puerto COM no encontrado**
**Síntomas:**
```
❌ No se encontraron puertos COM
```

**Solución:**
1. Abrir **Administrador de dispositivos**
2. Buscar en **Puertos (COM y LPT)**
3. Verificar que aparece `USB Serial Port (COM3)`
4. Si no aparece, reinstalar drivers

### **Problema 3: Comunicación fallida**
**Síntomas:**
```
❌ Respuesta no válida de balanza
```

**Solución:**
1. Verificar configuración de puerto
2. Probar diferentes baud rates
3. Revisar cable USB
4. Reiniciar balanza

## 🔍 **Debugging Avanzado**

### **Habilitar Logs Detallados**
```dart
// En scale_service.dart
print('🔧 Inicializando ScaleService...');
print('🔌 Conectando a balanza Aclas OS2X...');
print('📡 Respuesta de balanza: $response');
```

### **Probar Comunicación Manual**
```powershell
# Abrir PowerShell y ejecutar:
$port = New-Object System.IO.Ports.SerialPort "COM3", 9600, "None", 8, "One"
$port.Open()
$port.WriteLine("W`r`n")
Start-Sleep -Milliseconds 200
$data = $port.ReadExisting()
$port.Close()
Write-Host "Respuesta: $data"
```

## 📊 **Monitoreo en Tiempo Real**

### **Logs de la Aplicación**
```
🔧 Inicializando ScaleService...
✅ Canal de método configurado
🔌 Inicializando servicio Aclas OS2X...
🧪 Probando conexión con PowerShell...
📨 Datos de balanza: "ST,GS,   1.234kg"
✅ Comunicación exitosa con balanza Aclas OS2X
✅ Servicio Aclas OS2X conectado
📖 Iniciando lectura de peso...
⚖️ Peso leído: 1.234 kg
```

### **Indicadores Visuales**
- 🟢 **Conectada**: Balanza funcionando
- 🔴 **Desconectada**: Problema de conexión
- ⚖️ **Peso**: Actualización en tiempo real
- 🔄 **Lectura**: Proceso activo

## 🎯 **Integración con el POS**

### **Productos Pesados**
```dart
// Ejemplo de producto pesado
Product(
  name: "Manzanas",
  pricePerKg: 8000.0,  // $8,000 por kg
  unit: "kg",
  isWeighted: true,
  minWeight: 0.1,      // Mínimo 100g
  maxWeight: 5.0,      // Máximo 5kg
)
```

### **Cálculo Automático**
```dart
// El sistema calcula automáticamente:
Precio = Peso × Precio por kg
Total = 1.234 kg × $8,000 = $9,872
```

## 🚀 **Próximos Pasos**

### **Mejoras Planificadas**
1. **Detección Automática de Puerto**: Buscar automáticamente el puerto correcto
2. **Múltiples Protocolos**: Soporte para otras marcas de balanza
3. **Calibración**: Herramientas de calibración integradas
4. **Backup de Configuración**: Guardar configuraciones
5. **Reportes de Peso**: Estadísticas detalladas

### **Optimizaciones**
1. **Performance**: Mejorar velocidad de lectura
2. **Precisión**: Filtros de ruido
3. **Interfaz**: Mejoras en UX
4. **Compatibilidad**: Más modelos de balanza

## ✅ **Verificación de Funcionamiento**

### **Pasos para Verificar**
1. **Conectar balanza** por USB
2. **Ejecutar aplicación**: `flutter run -d windows`
3. **Ir al POS** y verificar conexión
4. **Colocar objeto** en la balanza
5. **Verificar** que el peso aparece en tiempo real
6. **Probar productos pesados** en el carrito

### **Señales de Éxito**
- ✅ Balanza aparece como "Conectada"
- ✅ Peso se actualiza en tiempo real
- ✅ Productos pesados calculan precio automáticamente
- ✅ Tare funciona correctamente
- ✅ No hay errores en la consola

## 🎉 **Conclusión**

El sistema ahora tiene una comunicación robusta y confiable con la balanza Aclas OS2X usando PowerShell, que es más estable en Windows que las librerías nativas. La arquitectura modular permite fácil mantenimiento y extensión para futuras mejoras.

**¡La comunicación con la balanza está lista para producción!** 🚀 