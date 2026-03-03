# 🧪 Guía de Prueba - Funcionalidad de Impresión

## ✅ Cómo Probar el Sistema de Impresión

### 📱 **Paso 1: Ejecutar la Aplicación**
```bash
flutter run -d windows
```

### 🛒 **Paso 2: Realizar una Venta de Prueba**
1. **Iniciar sesión**: Usuario: `admin`, Contraseña: `123456`
2. **Ir al POS**: Hacer clic en "Nueva Venta" en el dashboard
3. **Agregar productos**: 
   - Escanear código o agregar manualmente
   - Ejemplo: Buscar "PROD001" o cualquier producto
4. **Procesar pago**: Hacer clic en "Procesar Pago"
5. **Seleccionar método**: Elegir "Efectivo", "Tarjeta", etc.

### 🖨️ **Paso 3: Verificar Diálogo de Impresión**
Después de completar la venta, **automáticamente aparecerá**:

```
    ✅ ¡Venta Exitosa!
    Total: $XX,XXX
    Método: Efectivo
    
    ¿Desea imprimir el recibo?
    
    [  SÍ  ]    [  NO  ]
    
    Presiona Enter para imprimir o Escape para continuar
```

### 🎯 **Paso 4: Probar Funcionalidades**

#### ✨ **Autofocus en "SÍ"**
- El botón "SÍ" debe estar **destacado automáticamente**
- El foco debe estar en el botón "SÍ"

#### ⌨️ **Atajos de Teclado**
- **Enter**: Debe imprimir el recibo
- **Escape**: Debe continuar sin imprimir

#### 📝 **Modo Simulación**
Si no hay impresora conectada, el sistema funciona en **modo simulación**:
- Aparece mensaje: "Imprimiendo recibo..."
- En la consola se muestra el recibo formateado
- Mensaje de éxito: "El recibo se imprimió correctamente"

## 🔍 **Qué Observar**

### ✅ **Funcionamiento Correcto**
- ✅ Diálogo aparece automáticamente después de la venta
- ✅ Botón "SÍ" tiene foco (está destacado)
- ✅ Enter imprime el recibo
- ✅ Escape cancela la impresión
- ✅ Mensaje de "Imprimiendo recibo..." aparece
- ✅ En consola aparece el recibo formateado
- ✅ Mensaje de éxito al final

### ❌ **Posibles Problemas**
- ❌ No aparece el diálogo de impresión
- ❌ Botón "SÍ" no tiene foco
- ❌ Enter/Escape no funcionan
- ❌ Error al intentar imprimir

## 📋 **Logs de Depuración**
En la consola de Flutter, deberías ver estos mensajes:

```
🖨️ Inicializando PrintService...
🔍 Iniciando detección de impresora...
📱 Intentando conexión USB...
🔌 Intentando conexión por puerto serie...
⚠️ Impresora no detectada - Funcionará en modo simulación
✅ PrintService inicializado correctamente

// Al procesar una venta:
🖨️ Iniciando proceso de impresión...
🔍 Estado de la impresora: Conectada
🔌 Puerto: SIMULATION

// Al imprimir:
🖨️ Iniciando impresión de recibo...
📝 Simulando impresión del recibo:

=====================================
           SMART SELLER
            Sistema POS
          Recibo de Venta
=====================================
Fecha: 25/12/2023 14:30:25
Cajero: admin
Método: Efectivo
=====================================
[... resto del recibo ...]

✅ Recibo impreso exitosamente
```

## 🚀 **Prueba Avanzada**

### 🔧 **Con Impresora Real (Citizen TZ30-M01)**
1. **Conectar impresora**: USB o puerto serie
2. **Instalar drivers** si es necesario
3. **Ejecutar aplicación**
4. **Verificar detección**: En logs debe aparecer:
   ```
   ✅ Impresora conectada por USB
   ```
   o
   ```
   ✅ Impresora conectada por puerto serie
   ```
5. **Realizar venta**: El recibo debe imprimirse físicamente

### 📊 **Estado de la Impresora**
- **SIMULATION**: Modo simulación (sin impresora física)
- **USB**: Conectada por USB
- **COM1-COM8**: Conectada por puerto serie

## 🔧 **Solución de Problemas**

### 🚫 **Si no aparece el diálogo**
- Verificar que la venta se complete correctamente
- Revisar logs de errores en consola

### ⌨️ **Si Enter/Escape no funcionan**
- Verificar que el diálogo tenga foco
- Probar hacer clic en el diálogo primero

### 🖨️ **Si no imprime**
- En modo simulación, verificar logs en consola
- Con impresora real, verificar conexión y drivers

---

## 📞 **Soporte**
Si algo no funciona como se describe arriba, revisar:
1. **Logs de la consola** para mensajes de error
2. **Estado de conexión** de la impresora
3. **Versión de Flutter** y dependencias

¡La funcionalidad está **100% implementada** y lista para usar! 🎉 