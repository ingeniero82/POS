# Guía de Instalación - SmartSeller POS v1.0

## 📋 Requisitos Previos

### En el Computador de Desarrollo:
1. **Flutter SDK** instalado y configurado
2. **Visual Studio 2019 o superior** con:
   - Desktop development with C++
   - Windows 10/11 SDK
3. **Git** (opcional, para control de versiones)

### En el Computador de Pruebas:
1. **Windows 10/11 (64-bit)**
2. **Visual C++ Redistributable** (se instala automáticamente con el ejecutable)
3. **4GB RAM mínimo** (8GB recomendado)
4. **2GB espacio libre en disco**

---

## 🔨 Paso 1: Compilar el Ejecutable

### Opción A: Compilación Release (Recomendada)

```bash
# 1. Limpiar compilaciones anteriores
flutter clean

# 2. Obtener dependencias
flutter pub get

# 3. Compilar en modo release para Windows
flutter build windows --release
```

### Opción B: Compilación con Información de Versión

```bash
flutter build windows --release --build-name=1.0.0 --build-number=1
```

---

## 📦 Paso 2: Ubicación del Ejecutable

Después de compilar, el ejecutable estará en:

```
build\windows\x64\runner\Release\smart_seller.exe
```

**Carpeta completa necesaria:**
```
build\windows\x64\runner\Release\
```

Esta carpeta contiene:
- `smart_seller.exe` - Ejecutable principal
- `data\` - Carpeta con recursos de la aplicación
- `flutter_windows.dll` - Librerías de Flutter
- Otros archivos DLL necesarios

---

## 🚀 Paso 3: Crear Paquete de Instalación

### ⭐ Opción Recomendada: Instalador Profesional con Inno Setup

**El instalador profesional ya está configurado y listo para usar.**

1. **Instalar Inno Setup** (si no está instalado):
   - Descargar desde: https://jrsoftware.org/isdl.php
   - Instalar la versión 6.2 o superior
   - Asegurarse de instalar el compilador de línea de comandos

2. **Crear el instalador automáticamente:**
   ```batch
   instalador\crear_instalador.bat
   ```
   
   O manualmente:
   - Abrir Inno Setup Compiler
   - Abrir: `instalador\SmartSellerPOS_Installer.iss`
   - Presionar F9 para compilar

3. **El instalador se creará en:** `dist\SmartSellerPOS_Setup_v2.0.exe`

**Ventajas del instalador profesional:**
- ✅ Instalación automática de dependencias (Visual C++ Redistributable)
- ✅ Verificación de requisitos del sistema
- ✅ Configuración automática de permisos
- ✅ Creación de accesos directos
- ✅ Desinstalador incluido
- ✅ Interfaz profesional en español

### Opción Alternativa: Copiar Carpeta Completa (Método Simple)

1. Copiar toda la carpeta `build\windows\x64\runner\Release\`
2. Comprimir en ZIP
3. En el computador de pruebas:
   - Extraer el ZIP
   - Ejecutar `smart_seller.exe`
   - **Nota:** Este método requiere instalar Visual C++ Redistributable manualmente

---

## 📋 Paso 4: Instalación en Computador de Pruebas

### ⭐ Método Recomendado: Instalador Profesional

1. **Transferir el instalador** `SmartSellerPOS_Setup_v2.0.exe` al computador del cliente
2. **Ejecutar el instalador** (hacer clic derecho → "Ejecutar como administrador" si es necesario)
3. **Seguir el asistente:**
   - Aceptar los términos
   - Seleccionar carpeta de instalación (por defecto: `C:\Program Files\Smart Seller POS`)
   - Elegir crear accesos directos
   - El instalador instalará automáticamente Visual C++ Redistributable si es necesario
4. **Iniciar la aplicación** desde el acceso directo o el menú de inicio

### Método Alternativo: Carpeta Completa

1. **Copiar la carpeta Release completa** al computador de pruebas
2. **Instalar Visual C++ Redistributable** manualmente:
   - Descargar desde: https://aka.ms/vs/17/release/vc_redist.x64.exe
   - Instalar y reiniciar si es necesario
3. **Crear un acceso directo** de `smart_seller.exe` en el escritorio
4. **Ejecutar** el programa

---

## ⚙️ Paso 5: Configuración Inicial

Al ejecutar por primera vez:

1. **Credenciales por defecto:**
   - Usuario: `admin`
   - Contraseña: `123456`

2. **Cambiar contraseña** inmediatamente después del primer acceso

3. **Configurar datos de la empresa:**
   - Ir a Configuración → Empresa
   - Completar información fiscal
   - Configurar datos para DIAN

---

## 🔧 Solución de Problemas

### Error: "No se puede ejecutar la aplicación"

**Solución:**
- Instalar Visual C++ Redistributable:
  - Descargar desde: https://aka.ms/vs/17/release/vc_redist.x64.exe
  - Instalar y reiniciar

### Error: "Falta flutter_windows.dll"

**Solución:**
- Asegurarse de copiar TODA la carpeta Release, no solo el .exe
- Verificar que la carpeta `data\` esté presente

### Error: "No se puede conectar a la base de datos"

**Solución:**
- El programa creará la base de datos automáticamente
- Verificar permisos de escritura en la carpeta del programa
- Ejecutar como administrador si es necesario

### El programa no inicia

**Solución:**
1. Verificar que Windows Defender no bloquee el ejecutable
2. Verificar que todas las DLL estén presentes
3. Revisar el log de errores (si existe)

---

## 📝 Notas Importantes

1. **Base de Datos:**
   - Se crea automáticamente en la primera ejecución
   - Ubicación: `%APPDATA%\smart_seller\` o similar
   - Se puede hacer backup copiando esta carpeta

2. **Actualizaciones:**
   - Para actualizar, reemplazar el ejecutable y la carpeta `data\`
   - Hacer backup de la base de datos antes de actualizar

3. **Permisos:**
   - El programa necesita permisos de lectura/escritura
   - No requiere permisos de administrador para funcionar

4. **Rendimiento:**
   - Primera ejecución puede ser más lenta (inicialización)
   - Ejecuciones posteriores serán más rápidas

---

## ✅ Verificación de Instalación

Después de instalar, verificar:

- [ ] El programa inicia correctamente
- [ ] Se puede iniciar sesión con credenciales por defecto
- [ ] La base de datos se crea automáticamente
- [ ] Se pueden crear productos
- [ ] Se pueden procesar ventas
- [ ] Los reportes se generan correctamente

---

## 📞 Soporte

Si encuentras problemas durante la instalación:

1. Verificar que todos los requisitos estén cumplidos
2. Revisar los logs de error
3. Verificar permisos de archivos y carpetas
4. Intentar ejecutar como administrador

---

**Versión:** 1.0.0  
**Fecha:** Noviembre 2025  
**Desarrollador:** Oscar Mauricio González

