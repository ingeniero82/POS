# Integración de Balanzas en Smart Seller POS

## Descripción General

El sistema Smart Seller POS ahora incluye soporte completo para balanzas electrónicas, permitiendo la venta de productos pesados (a granel) con cálculo automático de precios basado en peso.

## Características Principales

### ✅ Funcionalidades Implementadas

1. **Comunicación con Balanzas**
   - Soporte para balanzas USB
   - Soporte para balanzas seriales
   - Detección automática de dispositivos
   - Múltiples protocolos de comunicación

2. **Productos Pesados**
   - Configuración de precio por kilogramo
   - Límites de peso mínimo y máximo
   - Cálculo automático de precios
   - Visualización diferenciada en la interfaz

3. **Interfaz de Usuario**
   - Widget de balanza en tiempo real
   - Indicadores de conexión y estado
   - Controles de tare, inicio/parada de lectura
   - Visualización clara del peso actual

4. **Gestión de Ventas**
   - Integración con el carrito de compras
   - Registro de peso en el historial de ventas
   - Cálculo automático de totales
   - Validación de límites de peso

## Arquitectura del Sistema

### Componentes Principales

```
lib/
├── services/
│   └── scale_service.dart          # Servicio de comunicación con balanzas
├── models/
│   └── product.dart               # Modelo de producto con soporte pesado
├── screens/
│   └── pos_screen.dart           # Pantalla POS con widget de balanza
└── controllers/
    └── pos_controller.dart       # Controlador con lógica de productos pesados
```

### Flujo de Datos

1. **Inicialización**: El `ScaleService` se inicializa automáticamente
2. **Detección**: Busca puertos USB y seriales disponibles
3. **Conexión**: Establece comunicación con la balanza seleccionada
4. **Lectura**: Recibe datos de peso en tiempo real
5. **Procesamiento**: Calcula precios y valida límites
6. **Venta**: Integra con el sistema de ventas existente

## Configuración de Productos Pesados

### Campos Nuevos en el Modelo Product

```dart
class Product {
  // ... campos existentes ...
  
  // Campos para productos pesados
  bool isWeighted = false;           // Indica si es producto pesado
  double? pricePerKg;               // Precio por kilogramo
  double? weight;                   // Peso actual (para productos pesados)
  double? minWeight;                // Peso mínimo para venta
  double? maxWeight;                // Peso máximo para venta
  
  // Campo calculado
  double get calculatedPrice {
    if (isWeighted && pricePerKg != null && weight != null) {
      return pricePerKg! * weight!;
    }
    return price;
  }
}
```

### Ejemplo de Configuración

```dart
// Producto normal
Product(
  name: "Coca Cola 350ml",
  price: 2500.0,
  unit: "unidad",
  isWeighted: false,
)

// Producto pesado
Product(
  name: "Manzanas",
  pricePerKg: 8000.0,  // $8,000 por kg
  unit: "kg",
  isWeighted: true,
  minWeight: 0.1,      // Mínimo 100g
  maxWeight: 5.0,      // Máximo 5kg
)
```

## Uso de la Balanza

### 1. Conectar Balanza

```dart
// En el controlador POS
await posController.connectScale();
```

### 2. Iniciar Lectura

```dart
// Iniciar lectura de peso
await posController.startScaleReading();

// Detener lectura
await posController.stopScaleReading();
```

### 3. Tarar Balanza

```dart
// Poner la balanza en cero
await posController.tareScale();
```

### 4. Agregar Producto Pesado

```dart
// Agregar producto usando peso de la balanza
posController.addWeightedProduct(product);
```

## Interfaz de Usuario

### Widget de Balanza

El widget `_ScaleWidget` muestra:

- **Estado de conexión**: Conectada/Desconectada
- **Peso actual**: En tiempo real con 3 decimales
- **Controles**:
  - Conectar/Desconectar
  - Iniciar/Detener lectura
  - Tare (poner en cero)

### Productos en el Carrito

Los productos pesados se muestran con:

- **Precio total**: Calculado automáticamente
- **Peso**: Mostrado en kg con 3 decimales
- **Indicador visual**: Color naranja para diferenciar

## Implementación Nativa

### Android (Kotlin)

```kotlin
// ScalePlugin.kt
class ScalePlugin: FlutterPlugin, MethodCallHandler {
    // Manejo de dispositivos USB
    private fun connectUsb(port: String, result: Result) {
        val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
        val device = usbManager.deviceList.values.find { it.deviceName == deviceName }
        
        if (device != null) {
            usbConnection = usbManager.openDevice(device)
            isConnected = true
            notifyConnectionChange(true)
        }
    }
    
    // Simulación de peso para testing
    private fun startWeightSimulation() {
        Thread {
            while (isReading && isConnected) {
                val randomWeight = 0.1 + Math.random() * 1.9
                currentWeight = randomWeight
                notifyWeightChange(randomWeight)
                Thread.sleep(1000)
            }
        }.start()
    }
}
```

### Protocolos Soportados

1. **Standard**: Formato básico de peso
2. **CAS**: Protocolo CAS común en balanzas
3. **Mettler**: Protocolo específico de balanzas Mettler
4. **Custom**: Protocolos personalizados

## Configuración de Base de Datos

### Nuevos Campos en la Tabla Products

```sql
ALTER TABLE products ADD COLUMN isWeighted INTEGER NOT NULL DEFAULT 0;
ALTER TABLE products ADD COLUMN pricePerKg REAL;
ALTER TABLE products ADD COLUMN weight REAL;
ALTER TABLE products ADD COLUMN minWeight REAL;
ALTER TABLE products ADD COLUMN maxWeight REAL;
```

### Migración Automática

El sistema detecta automáticamente si los campos existen y los agrega si es necesario.

## Casos de Uso

### 1. Frutas y Verduras

```dart
// Configurar producto
Product(
  name: "Plátanos",
  pricePerKg: 3500.0,
  unit: "kg",
  isWeighted: true,
  minWeight: 0.2,  // Mínimo 200g
  maxWeight: 10.0, // Máximo 10kg
  category: ProductCategory.frutasVerduras,
)
```

### 2. Carnes

```dart
Product(
  name: "Carne de Res",
  pricePerKg: 25000.0,
  unit: "kg",
  isWeighted: true,
  minWeight: 0.1,  // Mínimo 100g
  maxWeight: 5.0,  // Máximo 5kg
  category: ProductCategory.carnes,
)
```

### 3. Productos a Granel

```dart
Product(
  name: "Arroz",
  pricePerKg: 3000.0,
  unit: "kg",
  isWeighted: true,
  minWeight: 0.5,  // Mínimo 500g
  maxWeight: 25.0, // Máximo 25kg
  category: ProductCategory.abarrotes,
)
```

## Validaciones y Seguridad

### Límites de Peso

- **Peso mínimo**: Evita ventas de cantidades muy pequeñas
- **Peso máximo**: Previene errores de pesaje
- **Validación en tiempo real**: Durante la venta

### Manejo de Errores

```dart
// Ejemplos de validaciones
if (currentWeight <= 0) {
  Get.snackbar('Peso inválido', 'Coloca el producto en la balanza');
  return;
}

if (currentWeight < product.minWeight!) {
  Get.snackbar('Peso mínimo no alcanzado', 
    'El peso mínimo es ${product.minWeight!.toStringAsFixed(3)} kg');
  return;
}
```

## Testing y Simulación

### Modo de Prueba

Para desarrollo y testing, el sistema incluye:

- **Simulación de peso**: Valores aleatorios entre 0.1 y 2.0 kg
- **Conexión virtual**: Sin necesidad de balanza física
- **Logs detallados**: Para debugging

### Comandos de Testing

```dart
// Simular conexión exitosa
await scaleService.connect(port: "COM1");

// Simular lectura de peso
await scaleService.startReading();

// Verificar estado
print("Conectado: ${scaleService.isConnected}");
print("Peso actual: ${scaleService.currentWeight}");
```

## Configuración de Balanzas Específicas

### Balanza USB Genérica

```dart
await scaleService.connect(
  port: "USB:Generic Scale",
  baudRate: 9600,
  protocol: "standard",
);
```

### Balanza CAS

```dart
await scaleService.connect(
  port: "COM3",
  baudRate: 9600,
  protocol: "cas",
);
```

### Balanza Mettler

```dart
await scaleService.connect(
  port: "USB:Mettler Toledo",
  baudRate: 9600,
  protocol: "mettler",
);
```

## Mantenimiento y Troubleshooting

### Problemas Comunes

1. **Balanza no detectada**
   - Verificar conexión USB
   - Revisar permisos de dispositivo
   - Comprobar drivers instalados

2. **Lectura incorrecta**
   - Verificar protocolo de comunicación
   - Ajustar baud rate
   - Revisar formato de datos

3. **Conexión inestable**
   - Verificar cable USB
   - Reiniciar balanza
   - Actualizar drivers

### Logs de Debug

```dart
// Habilitar logs detallados
ScaleService.enableDebugLogs = true;

// Ver logs en consola
flutter logs
```

## Próximas Mejoras

### Funcionalidades Planificadas

1. **Múltiples Balanzas**: Soporte para varias balanzas simultáneas
2. **Calibración**: Herramientas de calibración integradas
3. **Backup de Configuración**: Guardar configuraciones de balanzas
4. **Reportes de Peso**: Estadísticas de productos vendidos por peso
5. **Integración con Impresoras**: Etiquetas con peso y precio

### Optimizaciones

1. **Performance**: Mejoras en la velocidad de lectura
2. **Precisión**: Algoritmos de filtrado de ruido
3. **Interfaz**: Mejoras en la UX del widget de balanza
4. **Compatibilidad**: Soporte para más modelos de balanzas

## Conclusión

La integración de balanzas en Smart Seller POS proporciona una solución completa para la venta de productos pesados, manteniendo la simplicidad de uso y la robustez del sistema. La arquitectura modular permite fácil extensión y personalización según las necesidades específicas de cada establecimiento.

---

**Nota**: Esta documentación se actualiza regularmente. Para la versión más reciente, consulta el repositorio del proyecto. 