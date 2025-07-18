# Configuración de Impresora Citizen TZ30-M01

## Descripción
Esta guía explica cómo configurar y usar la impresora térmica Citizen TZ30-M01 con el sistema Smart Seller POS.

## Características Implementadas

### ✅ Funcionalidades Completadas
- **Pregunta automática de impresión**: Después de cada venta exitosa, aparece un diálogo preguntando si desea imprimir el recibo
- **Autofocus en "SÍ"**: El botón "SÍ" tiene foco automático al abrir el diálogo
- **Impresión con Enter**: Presionar Enter imprime el recibo directamente
- **Escape para cancelar**: Presionar Escape continúa sin imprimir
- **Soporte USB y Serie**: Conectividad tanto por USB como por puerto serie
- **Formato de recibo profesional**: Recibo con formato ESC/POS optimizado para impresora térmica

### 🎯 Flujo de Uso
1. **Completar venta**: Procesar pago normalmente en el POS
2. **Confirmación automática**: Aparece diálogo "¿Desea imprimir el recibo?"
3. **Responder rápidamente**: 
   - **Enter** o **Clic en SÍ**: Imprime recibo
   - **Escape** o **Clic en NO**: Continúa sin imprimir
4. **Impresión automática**: El sistema detecta la impresora y imprime

## Configuración de Hardware

### Conexión USB
1. Conectar la impresora Citizen TZ30-M01 por USB
2. Instalar drivers si es necesario
3. El sistema detectará automáticamente la impresora

### Conexión Serie
1. Conectar por puerto serie (RS-232)
2. Configuración automática:
   - **Baudios**: 9600
   - **Bits de datos**: 8
   - **Paridad**: Ninguna
   - **Bits de parada**: 1
3. El sistema probará puertos COM1-COM8 automáticamente

## Formato del Recibo

### Contenido del Recibo
```
=====================================
           SMART SELLER
            Sistema POS
          Recibo de Venta
=====================================
Fecha: 25/12/2023 14:30:25
Cajero: admin
Método: Efectivo
=====================================
PRODUCTO         CANT      PRECIO
=====================================
Manzana Roja
1.250 kg         $1.500    $1.875

Leche Entera
2 litro          $2.500    $5.000
=====================================
                Subtotal: $6.875
                IVA(19%): $1.306
                
                TOTAL: $8.181
=====================================

        ¡Gracias por su compra!
            Vuelva pronto

=====================================
Impreso: 25/12/2023 14:30:28
```

### Características del Formato
- **Ancho**: 48 caracteres (papel de 80mm)
- **Fuente**: Monoespaciada estándar
- **Negrita**: Título y total
- **Alineación**: Centro para títulos, derecha para totales
- **Separadores**: Líneas de igual (=)

## Comandos ESC/POS Soportados

### Comandos Básicos
- `ESC @`: Inicializar impresora
- `ESC a`: Alineación (izquierda, centro, derecha)
- `ESC E`: Texto en negrita
- `ESC !`: Tamaño de fuente
- `ESC -`: Subrayado
- `GS V`: Cortar papel
- `ESC d`: Alimentar líneas

### Configuración Automática
- **Inicialización**: Automática al conectar
- **Detección**: Busca impresora en USB primero, luego serie
- **Reconexión**: Automática en caso de desconexión

## Manejo de Errores

### Mensajes de Error
- **"Impresora no detectada"**: Verificar conexión USB/serie
- **"Error de impresión"**: Revisar papel y estado de impresora
- **"Impresora ocupada"**: Esperar a que termine trabajo anterior

### Resolución de Problemas
1. **Impresora no detectada**:
   - Verificar conexión USB
   - Revisar drivers instalados
   - Probar puertos serie COM1-COM8

2. **No imprime**:
   - Verificar papel en la impresora
   - Comprobar que esté encendida
   - Reiniciar aplicación

3. **Formato incorrecto**:
   - Verificar configuración de ancho de papel
   - Asegurar que sea impresora térmica de 80mm

## Pruebas de Impresión

### Recibo de Prueba
El sistema incluye una función de prueba que se puede ejecutar desde el código:
```dart
await PrintService.instance.printTestReceipt();
```

### Verificar Funcionalidad
1. Conectar impresora
2. Realizar venta de prueba
3. Verificar que aparezca diálogo de impresión
4. Probar tanto "SÍ" como "NO"
5. Verificar que Enter e Escape funcionan

## Compatibilidad

### Impresoras Compatibles
- **Citizen TZ30-M01** (principal)
- Otras impresoras térmicas con comandos ESC/POS
- Impresoras de recibo de 80mm

### Sistemas Operativos
- **Windows**: Completamente soportado
- **Android**: Preparado para implementación futura
- **iOS**: Preparado para implementación futura

## Mantenimiento

### Limpieza Regular
- Limpiar cabezal térmico mensualmente
- Usar papel de calidad térmica
- Mantener impresora libre de polvo

### Actualizaciones
- El servicio de impresión se actualiza automáticamente
- Nuevos formatos de recibo se pueden agregar fácilmente
- Soporte para nuevas impresoras configurable

## Configuración Avanzada

### Personalización de Recibo
El formato del recibo se puede personalizar modificando:
- `PrintService.printReceipt()`: Contenido del recibo
- Comandos ESC/POS: Formato y estilo
- Ancho de papel: Configuración de columnas

### Integración con Otros Sistemas
- API REST para impresión remota
- Soporte para múltiples impresoras
- Logs de impresión para auditoría

## Soporte Técnico

### Documentación Adicional
- Comandos ESC/POS: [Manual oficial]
- Drivers Citizen: [Sitio oficial]
- Configuración Windows: [Documentación Microsoft]

### Contacto
Para soporte técnico adicional, contactar al equipo de desarrollo.

---

**Nota**: Esta funcionalidad está optimizada para uso profesional en puntos de venta. Se recomienda probar completamente antes de usar en producción. 