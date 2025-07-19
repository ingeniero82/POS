# 📊 Módulo de Peso - Smart Seller POS

## 🎯 **Problemas Solucionados**

### ✅ **1. Productos pesados SIN campo de cantidad**
- **Antes**: Los productos pesados tenían campo de cantidad (incorrecto)
- **Ahora**: Los productos pesados se liquidan automáticamente por peso
- **Beneficio**: Funciona como un POS profesional real

### ✅ **2. Peso SIEMPRE visible**
- **Antes**: Solo aparecía para productos pesados
- **Ahora**: El peso está siempre visible en la pantalla POS
- **Beneficio**: Como balanzas profesionales reales

### ✅ **3. Simulación funcional**
- **Ahora**: Simula peso real que cambia cada 10 segundos
- **Pesos simulados**: 0.000, 0.250, 0.500, 1.250, 2.100, 0.750 kg
- **Beneficio**: Puedes probar todo sin balanza física

## 🚀 **Cómo Usar**

### **Paso 1: Ejecutar la aplicación**
```bash
flutter run -d windows
```

### **Paso 2: Ir al POS**
- Inicia sesión con `admin` / `123456`
- Ve a **Punto de Venta** en el menú

### **Paso 3: Probar productos pesados**
- Escanea o busca: `MANZ001` (Manzanas)
- Escanea o busca: `CRES001` (Carne)
- Escanea o busca: `PLAT001` (Plátanos)

### **Paso 4: Ver la diferencia**
- **Productos normales**: Aparece campo de cantidad
- **Productos pesados**: NO aparece campo de cantidad
- **Peso**: SIEMPRE visible en ambos casos

## 📱 **Interfaz del POS**

### **Para productos NORMALES:**
```
┌─────────────────────────────────┐
│ Coca Cola 350ml                 │
│ Código: COCA001                 │
│ Precio: $2,500                  │
│ Stock: 50                       │
│                                 │
│ [Cantidad: 1        ] [📝]     │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ Peso: 0.000 kg   🔴 Descon │ │
│ │ [Conectar] [Tare] [Iniciar] │ │
│ └─────────────────────────────┘ │
│                                 │
│ [Agregar al Carrito]            │
│ [Cancelar]                      │
└─────────────────────────────────┘
```

### **Para productos PESADOS:**
```
┌─────────────────────────────────┐
│ Manzanas Rojas                  │
│ Código: MANZ001                 │
│ Precio: $0 (calculado por peso) │
│ Stock: 999999                   │
│                                 │
│ ⚠️ Producto por peso: La cantidad│
│   se determina automáticamente  │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ Peso: 1.250 kg   🟢 Conect │ │
│ │ Precio/kg: $6,500           │ │
│ │ Total: $8,125               │ │
│ │ [Conectar] [Tare] [Iniciar] │ │
│ └─────────────────────────────┘ │
│                                 │
│ [Agregar Producto Pesado]       │
│ [Cancelar]                      │
└─────────────────────────────────┘
```

## 🔧 **Funcionalidades**

### **Simulación de Peso**
- **0-9 seg**: 0.000 kg (sin peso)
- **10-19 seg**: 0.250 kg (manzana pequeña)
- **20-29 seg**: 0.500 kg (manzana mediana)
- **30-39 seg**: 1.250 kg (varias manzanas)
- **40-49 seg**: 2.100 kg (carne)
- **50-59 seg**: 0.750 kg (plátanos)

### **Productos Pesados de Ejemplo**
- **MANZ001**: Manzanas - $6,500/kg
- **PLAT001**: Plátanos - $3,500/kg  
- **PAPA001**: Papas - $2,800/kg
- **CRES001**: Carne de Res - $28,000/kg
- **POLL001**: Pollo - $12,000/kg
- **ARRO001**: Arroz - $4,000/kg
- **FRIJ001**: Frijoles - $5,500/kg

### **Controles de Balanza**
- **Conectar**: Simula conexión con balanza
- **Tare**: Pone peso en 0.000 kg
- **Iniciar**: Comienza lectura de peso
- **Detener**: Para lectura de peso

## 🛠️ **Para Conectar Balanza Real**

### **Requisitos**
- Balanza **Aclas OS2X** conectada por USB
- Drivers instalados en Windows
- Puerto COM reconocido

### **Pasos**
1. Conectar balanza Aclas OS2X por USB
2. Verificar que Windows reconoce el dispositivo
3. Identificar puerto COM en Administrador de dispositivos
4. Editar `scale_service.dart` para usar comunicación real
5. Reemplazar simulación con `RealScaleService`

Ver archivo `scale_service_real.dart` para código de ejemplo.

## 📝 **Debugging**

### **Botón Debug**
- Hay un botón 🐛 en la barra de herramientas del POS
- Muestra información detallada sobre la balanza
- Útil para diagnosticar problemas

### **Logs en Consola**
```
🔧 Inicializando ScaleService...
✅ Canal de método configurado
🔌 Simulando conexión con balanza...
✅ Balanza simulada conectada
📖 Iniciando lectura de peso...
✅ Lectura de peso iniciada
```

## 🎉 **Beneficios del Sistema**

### **Como POS Profesional**
- ✅ Peso siempre visible
- ✅ Productos pesados sin cantidad
- ✅ Cálculo automático de precios
- ✅ Interfaz diferenciada por tipo de producto

### **Para el Usuario**
- ✅ Fácil de usar
- ✅ Menos errores
- ✅ Proceso más rápido
- ✅ Información clara y precisa

### **Para el Negocio**
- ✅ Liquidación exacta por peso
- ✅ Control de inventario
- ✅ Facturación precisa
- ✅ Integración completa con POS

---

**¡El módulo de peso está listo para usar!** 🚀 