# Instalador Profesional Smart Seller POS

## 📋 Descripción

Este instalador profesional ha sido creado con **Inno Setup** para proporcionar una experiencia de instalación completa y sin problemas para los clientes.

## 🚀 Características

- ✅ Verificación automática de requisitos del sistema
- ✅ Instalación automática de Visual C++ Redistributable
- ✅ Configuración automática de permisos
- ✅ Creación de accesos directos
- ✅ Interfaz profesional en español e inglés
- ✅ Desinstalador completo incluido

## 📦 Requisitos para Crear el Instalador

### 1. Inno Setup
Descargar e instalar desde: https://jrsoftware.org/isdl.php
- Versión recomendada: 6.2 o superior
- Durante la instalación, asegurarse de instalar el compilador de línea de comandos

### 2. Flutter SDK
- Flutter debe estar instalado y configurado
- Visual Studio 2019 o superior con componentes de C++

## 🔨 Pasos para Crear el Instalador

### Opción 1: Script Automático (Recomendado)

1. Abrir PowerShell o CMD como administrador
2. Navegar a la carpeta del proyecto
3. Ejecutar:
```batch
instalador\crear_instalador.bat
```

El script:
- Verificará que el ejecutable esté compilado
- Compilará la aplicación si es necesario
- Creará el instalador automáticamente

### Opción 2: Manual

1. **Compilar la aplicación:**
```bash
flutter clean
flutter pub get
flutter build windows --release
```

2. **Abrir Inno Setup Compiler:**
   - Buscar "Inno Setup Compiler" en el menú de inicio
   - Abrir el archivo: `instalador\SmartSellerPOS_Installer.iss`

3. **Compilar:**
   - Presionar F9 o ir a Build → Compile
   - El instalador se creará en la carpeta `dist\`

## 📁 Estructura de Archivos

```
instalador/
├── SmartSellerPOS_Installer.iss    # Script principal de Inno Setup
├── crear_instalador.bat            # Script para crear el instalador automáticamente
└── LEEME_INSTALADOR.md            # Este archivo

dist/
└── SmartSellerPOS_Setup_v2.0.exe  # Instalador generado (después de compilar)
```

## 🎯 Instalación en el Cliente

1. **Ejecutar el instalador:**
   - Hacer doble clic en `SmartSellerPOS_Setup_v2.0.exe`
   - Si Windows muestra advertencia de seguridad, hacer clic en "Más información" → "Ejecutar de todos modos"

2. **Seguir el asistente:**
   - Aceptar los términos (si los hay)
   - Seleccionar carpeta de instalación (por defecto: `C:\Program Files\Smart Seller POS`)
   - Elegir crear accesos directos
   - El instalador instalará automáticamente Visual C++ Redistributable si es necesario

3. **Iniciar la aplicación:**
   - Desde el acceso directo en el escritorio
   - O desde el menú de inicio: Smart Seller POS

## 🔧 Solución de Problemas

### El instalador no se crea

**Problema:** Error al compilar con Inno Setup
**Solución:**
- Verificar que Inno Setup esté instalado correctamente
- Verificar que la ruta en `crear_instalador.bat` sea correcta
- Compilar manualmente desde Inno Setup Compiler para ver errores detallados

### El instalador no funciona en el cliente

**Problema:** El instalador no inicia o da error
**Solución:**
- Verificar que el cliente tenga Windows 10 o superior (64-bit)
- Ejecutar como administrador
- Verificar que Windows Defender no bloquee el archivo

### La aplicación no inicia después de instalar

**Problema:** Error al ejecutar la aplicación
**Solución:**
- Verificar que Visual C++ Redistributable se haya instalado correctamente
- Revisar `SOLUCION_PROBLEMAS_EJECUTABLE.md`
- Verificar permisos de la carpeta de instalación

## 📝 Personalización

Para personalizar el instalador, editar `SmartSellerPOS_Installer.iss`:

- **Cambiar versión:** Modificar `#define MyAppVersion`
- **Cambiar nombre:** Modificar `#define MyAppName`
- **Agregar archivos:** Agregar entradas en la sección `[Files]`
- **Cambiar icono:** Especificar ruta en `SetupIconFile`

## ✅ Verificación

Después de crear el instalador, verificar:

- [ ] El archivo `.exe` se creó en la carpeta `dist\`
- [ ] El tamaño del instalador es razonable (50-200 MB aproximadamente)
- [ ] Probar la instalación en una máquina limpia
- [ ] Verificar que la aplicación inicia correctamente
- [ ] Verificar que el desinstalador funciona

## 📞 Soporte

Si tiene problemas al crear o usar el instalador, verificar:

1. Logs de Inno Setup (si compila manualmente)
2. Logs de Flutter (si hay problemas de compilación)
3. Documentación de Inno Setup: https://jrsoftware.org/ishelp/

---

**Versión:** 2.0  
**Última actualización:** 2025


