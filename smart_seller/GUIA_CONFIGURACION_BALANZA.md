# Guía de Configuración de Balanza Aclas OS2X

## 📋 Requisitos Previos

### Hardware
- Balanza Aclas OS2X
- Cable USB a RS232 (incluido con la balanza)
- Puerto COM disponible en tu computadora

### Software
- Windows 10/11
- Drivers de la balanza instalados
- Smart Seller POS ejecutándose

## 🔧 Pasos de Configuración

### 1. Instalación de Drivers

1. **Descargar drivers** desde el sitio oficial de Aclas
2. **Instalar drivers** siguiendo las instrucciones del fabricante
3. **Verificar instalación** en Administrador de dispositivos

### 2. Conexión Física

1. **Conectar cable USB** de la balanza al puerto USB de la computadora
2. **Verificar que Windows detecte** el dispositivo como puerto COM
3. **Anotar el número de puerto COM** asignado (ej: COM3)

### 3. Configuración en Smart Seller

#### Acceder a Configuración de Balanza

1. **Abrir Smart Seller POS**
2. **Ir a Configuración de Peso** (módulo de peso)
3. **Hacer clic en el ícono de configuración** (⚙️) en la barra superior
4. **Se abrirá la pantalla de configuración de balanza**

#### Configurar Parámetros

1. **Seleccionar Puerto COM**
   - Por defecto: COM3
   - Si no funciona, probar con COM1, COM2, COM4, etc.

2. **Configurar Baud Rate**
   - Por defecto: 9600
   - Si no funciona, probar con 19200, 38400

3. **Otros parámetros**
   - Data Bits: 8
   - Parity: None
   - Stop Bits: 1

### 4. Probar Conexión

1. **Hacer clic en "Probar Conexión"**
2. **Verificar que aparezca "Conexión exitosa"**
3. **Si falla, revisar:**
   - Puerto COM correcto
   - Cable bien conectado
   - Balanza encendida
   - Drivers instalados

### 5. Iniciar Lectura

1. **Hacer clic en "Conectar"**
2. **Verificar que el estado cambie a "Conectado"**
3. **Hacer clic en "Iniciar Lectura"**
4. **Colocar un peso en la balanza para verificar**

## 🔍 Solución de Problemas

### Problema: "No se pudo conectar a la balanza"

**Posibles causas:**
- Puerto COM incorrecto
- Balanza no encendida
- Cable mal conectado
- Drivers no instalados
- Otro programa usando el puerto

**Soluciones:**
1. **Verificar Administrador de dispositivos**
   - Buscar "Puertos (COM y LPT)"
   - Verificar que aparezca el dispositivo Aclas

2. **Probar diferentes puertos COM**
   - Cambiar en la configuración
   - Probar uno por uno

3. **Reiniciar balanza**
   - Apagar y encender la balanza
   - Desconectar y reconectar cable

4. **Verificar que no hay otros programas**
   - Cerrar otros programas que usen puertos COM
   - Reiniciar Smart Seller POS

### Problema: "Peso no se actualiza"

**Posibles causas:**
- Balanza en modo incorrecto
- Protocolo de comunicación incorrecto
- Lectura no iniciada

**Soluciones:**
1. **Verificar modo de balanza**
   - Debe estar en modo de transmisión
   - Consultar manual de la balanza

2. **Iniciar lectura**
   - Hacer clic en "Iniciar Lectura"
   - Verificar que el estado sea "Activa"

3. **Tarar balanza**
   - Hacer clic en "Tarar Balanza"
   - Verificar que el peso vaya a 0.000

### Problema: "Peso incorrecto o inestable"

**Posibles causas:**
- Balanza no calibrada
- Superficie inestable
- Interferencias

**Soluciones:**
1. **Calibrar balanza**
   - Seguir instrucciones del fabricante
   - Usar pesos de calibración

2. **Verificar superficie**
   - Balanza sobre superficie estable
   - Lejos de vibraciones

3. **Verificar conexión**
   - Cable bien conectado
   - Sin interferencias electromagnéticas

## 📊 Comandos de la Balanza

### Comandos Básicos
- `W\r\n` - Solicitar peso
- `T\r\n` - Tarar balanza
- `Z\r\n` - Peso en cero

### Respuestas Esperadas
- `ST,GS,0.250kg` - Peso estable
- `ST,NET,0.250kg` - Peso neto
- `US,GS,0.250kg` - Peso inestable

## 🔧 Configuración Avanzada

### Modificar Puerto COM
```dart
// En lib/services/aclas_os2x_service.dart
static const String _targetPort = 'COM3'; // Cambiar aquí
```

### Modificar Baud Rate
```dart
// En lib/services/aclas_os2x_service.dart
static const int _baudRate = 9600; // Cambiar aquí
```

### Agregar Nuevos Patrones de Respuesta
```dart
// En lib/services/aclas_os2x_service.dart
final patterns = [
  RegExp(r'ST,GS,\s*([0-9]+\.[0-9]+)kg'),
  RegExp(r'ST,NET,\s*([0-9]+\.[0-9]+)kg'),
  RegExp(r'US,GS,\s*([0-9]+\.[0-9]+)kg'),
  // Agregar nuevos patrones aquí
];
```

## 📱 Uso en el POS

### Agregar Producto Pesado
1. **Ir a Configuración de Peso**
2. **Hacer clic en "Nuevo Producto"**
3. **Configurar:**
   - Nombre del producto
   - Código
   - Precio por kilogramo
   - Categoría
   - Peso mínimo/máximo (opcional)

### Vender Producto Pesado
1. **En el POS, buscar producto pesado**
2. **Seleccionar producto**
3. **Colocar peso en balanza**
4. **El precio se calcula automáticamente**
5. **Agregar al carrito**

## 🆘 Soporte

### Logs de Debug
Los logs se muestran en la consola de Flutter:
```
🔌 Conectando a balanza Aclas OS2X...
📋 Puertos COM detectados: [COM1, COM2, COM3]
✅ Servicio Aclas OS2X conectado exitosamente
📊 Peso actualizado: 0.250 kg
```

### Información de Contacto
- **Fabricante:** Aclas
- **Modelo:** OS2X
- **Soporte técnico:** Consultar manual de la balanza

## ✅ Checklist de Verificación

- [ ] Drivers instalados
- [ ] Cable conectado
- [ ] Puerto COM identificado
- [ ] Balanza encendida
- [ ] Conexión exitosa
- [ ] Lectura iniciada
- [ ] Peso se actualiza
- [ ] Productos pesados configurados
- [ ] Prueba de venta exitosa

## 🔄 Mantenimiento

### Revisión Mensual
1. **Verificar conexión**
2. **Probar lectura de peso**
3. **Calibrar balanza si es necesario**
4. **Limpiar superficie de la balanza**

### Actualizaciones
- **Mantener drivers actualizados**
- **Verificar actualizaciones de Smart Seller POS**
- **Consultar manual de la balanza para actualizaciones**

---

**Nota:** Esta guía está específicamente diseñada para la balanza Aclas OS2X. Para otros modelos, consultar la documentación correspondiente. 