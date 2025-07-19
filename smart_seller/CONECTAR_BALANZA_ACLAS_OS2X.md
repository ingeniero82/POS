# 🔧 Cómo Conectar la Balanza Aclas OS2X

## ✅ **Estado Actual**
- ✅ Código de comunicación real implementado
- ✅ Protocolo Aclas OS2X configurado
- ✅ Dependencias instaladas (libserialport)
- ✅ Detección automática de puertos COM

## 📋 **Pasos para Conectar la Balanza REAL**

### **Paso 1: Verificar Conexión Física**
1. Conecta tu balanza **Aclas OS2X** por USB
2. Enciende la balanza
3. Espera que Windows la reconozca (sonido de dispositivo conectado)

### **Paso 2: Verificar Puerto COM**
1. Abre **Administrador de dispositivos** (Device Manager)
2. Busca en **Puertos (COM y LPT)**
3. Deberías ver algo como: `USB Serial Port (COM3)` o `Prolific USB-to-Serial (COM5)`
4. **Anota el número del puerto** (ej: COM3, COM5, etc.)

### **Paso 3: Probar Comunicación**
1. Ejecuta la aplicación: `flutter run -d windows`
2. Ve al **POS** (Punto de Venta)
3. Busca el botón **🐛 Debug** al lado de los modos
4. Haz clic en **Debug** para probar la conexión

### **Paso 4: Leer los Logs**
En la consola de Flutter verás:
```
🔍 Buscando balanza Aclas OS2X...
📋 Puertos disponibles: [COM1, COM3, COM5]
🔌 Probando puerto: COM3
📡 Respuesta de COM3: ST,GS,   1.234kg
✅ Conectado a balanza Aclas OS2X en puerto COM3
```

### **Paso 5: Usar la Balanza**
1. Coloca un objeto en la balanza
2. El peso debería aparecer en tiempo real
3. Busca productos pesados: `MANZ001`, `CRES001`, `PLAT001`
4. Verifica que el precio se calcule automáticamente

## 🔧 **Comandos Específicos Aclas OS2X**

### **Comandos que Envía la Aplicación:**
- `W\r\n` - Solicitar peso
- `T\r\n` - Tare (poner en cero)

### **Respuestas Esperadas:**
- `ST,GS,   1.234kg\r\n` - Peso estable
- `ST,NET,  0.500kg\r\n` - Peso neto
- `US,GS,   0.000kg\r\n` - Peso inestable

## 🔍 **Solución de Problemas**

### **Problema: No se detecta la balanza**
**Síntomas:**
```
🔍 Buscando balanza Aclas OS2X...
📋 Puertos disponibles: []
❌ No se encontraron puertos COM
```

**Solución:**
1. Verificar que la balanza esté encendida
2. Comprobar cable USB
3. Instalar drivers desde el CD de la balanza
4. Reiniciar Windows y reconectar

### **Problema: Puerto detectado pero no responde**
**Síntomas:**
```
🔌 Probando puerto: COM3
❌ Puerto COM3 no responde como Aclas OS2X
```

**Solución:**
1. Verificar configuración de la balanza:
   - Baudios: 9600
   - Bits de datos: 8
   - Paridad: Ninguna
   - Bits de parada: 1
2. Probar con diferentes puertos COM
3. Verificar que la balanza esté en modo "PC" o "Host"

### **Problema: Respuesta incorrecta**
**Síntomas:**
```
📡 Respuesta raw: ��@#$%^&*
❌ Error parseando respuesta
```

**Solución:**
1. Verificar velocidad de comunicación (9600 bps)
2. Comprobar configuración de la balanza
3. Probar con cable USB diferente

## 📊 **Configuración de la Balanza**

### **Menú de la Balanza Aclas OS2X:**
1. Presiona **MENÚ** en la balanza
2. Navega a **Configuración** → **Comunicación**
3. Configura:
   - **Modo**: PC o Host
   - **Velocidad**: 9600 bps
   - **Formato**: Estándar
   - **Protocolo**: Continuo o Comando

### **Configuración Recomendada:**
```
Modo: PC/Host
Velocidad: 9600 bps
Bits datos: 8
Paridad: Ninguna
Bits parada: 1
Control flujo: Ninguno
Protocolo: Comando (envía solo cuando se solicita)
```

## 🆘 **Si No Funciona**

### **Plan B: Usar Simulación Temporal**
Si no puedes conectar la balanza inmediatamente, puedes activar la simulación temporal:

1. Abre `lib/services/scale_service.dart`
2. En la línea 49, cambia:
   ```dart
   await _connectToAclasOS2X();
   ```
   por:
   ```dart
   await _simulateConnectionForTesting();
   ```

3. Agrega este método:
   ```dart
   Future<void> _simulateConnectionForTesting() async {
     print('🔌 Simulación temporal activada');
     await Future.delayed(const Duration(milliseconds: 500));
     _isConnected = true;
     _connectionController.add(true);
   }
   ```

### **Contactar Soporte**
Si sigues teniendo problemas:
1. Anota el modelo exacto de tu balanza
2. Copia los logs de la consola
3. Verifica el número de puerto COM
4. Toma foto de la configuración de la balanza

---

## 🎯 **Resultado Esperado**

Cuando todo funcione correctamente verás:
```
✅ Conectado a balanza Aclas OS2X en puerto COM3
📖 Iniciando lectura de peso real...
✅ Lectura de peso real iniciada
📊 Peso leído: 1.234 kg
📊 Peso leído: 1.235 kg
📊 Peso leído: 1.234 kg
```

**¡Tu balanza Aclas OS2X estará comunicando en tiempo real!** 🚀 