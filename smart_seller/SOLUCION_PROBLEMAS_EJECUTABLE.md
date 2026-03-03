# 🔧 SOLUCIÓN DE PROBLEMAS - Smart Seller POS

## ❌ **Problema:** El ejecutable no abre en la PC del cliente

### 📋 **Diagnóstico Paso a Paso:**

#### **1. Verificar Requisitos del Sistema**
```
✅ Windows 10 o superior (64-bit)
✅ Mínimo 4GB RAM
✅ 500MB espacio libre
✅ .NET Framework 4.7.2 o superior
```

#### **2. Verificar Archivos Requeridos**
El cliente debe tener estos archivos en la misma carpeta:
- ✅ `smart_seller.exe` (archivo principal)
- ✅ `flutter_windows.dll` (librería Flutter)
- ✅ `sqlite3.dll` (base de datos)
- ✅ `sqlite3_flutter_libs_plugin.dll` (plugin SQLite)
- ✅ Carpeta `data/` (recursos de la aplicación)

#### **3. Soluciones por Tipo de Error**

##### **🔴 Error: "No se puede abrir el archivo"**
**Causa:** Archivos faltantes o corruptos
**Solución:**
1. Extraer TODOS los archivos del ZIP
2. Verificar que no falte ningún archivo
3. Ejecutar como administrador

##### **🔴 Error: "Aplicación bloqueada por Windows Defender"**
**Causa:** Antivirus detecta como amenaza
**Solución:**
1. Agregar excepción en Windows Defender
2. Agregar excepción en antivirus de terceros
3. Ejecutar desde carpeta confiable

##### **🔴 Error: "Falta DLL"**
**Causa:** Librerías del sistema faltantes
**Solución:**
1. Instalar Visual C++ Redistributable 2019
2. Instalar .NET Framework 4.7.2
3. Actualizar Windows

##### **🔴 Error: "Acceso denegado"**
**Causa:** Permisos insuficientes
**Solución:**
1. Clic derecho → "Ejecutar como administrador"
2. Desactivar UAC temporalmente
3. Mover a carpeta sin restricciones

##### **🔴 Error: "No responde" o pantalla negra**
**Causa:** Conflicto de drivers o recursos
**Solución:**
1. Reiniciar PC
2. Actualizar drivers de gráficos
3. Ejecutar en modo compatible

### 🛠️ **Pasos de Solución Rápida:**

#### **Paso 1: Verificación Básica**
```powershell
# Abrir PowerShell como administrador y ejecutar:
Get-ChildItem "C:\ruta\a\SmartSellerPOS_Cliente_v3" -Recurse
```

#### **Paso 2: Verificar Dependencias**
```powershell
# Verificar si .NET Framework está instalado:
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP" -Recurse | Get-ItemProperty -Name version -EA 0 | Where { $_.PSChildName -Match '^(?!S)\p{L}'} | Select PSChildName, version
```

#### **Paso 3: Ejecutar con Diagnóstico**
```powershell
# Ejecutar desde línea de comandos para ver errores:
cd "C:\ruta\a\SmartSellerPOS_Cliente_v3"
.\smart_seller.exe
```

### 📞 **Información para el Cliente:**

#### **Datos Necesarios para Diagnóstico:**
1. **Sistema Operativo:** Windows 10/11, versión exacta
2. **Arquitectura:** 32-bit o 64-bit
3. **Antivirus:** Qué antivirus tiene instalado
4. **Error específico:** Mensaje exacto que aparece
5. **Logs:** Archivos de error si los hay

#### **Comandos para el Cliente:**
```cmd
# Verificar sistema:
systeminfo | findstr /C:"OS Name" /C:"OS Version" /C:"System Type"

# Verificar archivos:
dir SmartSellerPOS_Cliente_v3

# Ejecutar con debug:
smart_seller.exe --verbose
```

### 🔧 **Soluciones Avanzadas:**

#### **1. Crear Script de Instalación**
```batch
@echo off
echo Instalando Smart Seller POS...
echo Verificando requisitos...

REM Verificar .NET Framework
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Version

REM Verificar archivos
if not exist "smart_seller.exe" (
    echo ERROR: Archivo principal faltante
    pause
    exit /b 1
)

if not exist "flutter_windows.dll" (
    echo ERROR: Librería Flutter faltante
    pause
    exit /b 1
)

echo Ejecutando aplicación...
start smart_seller.exe
```

#### **2. Configurar Excepciones de Antivirus**
- **Windows Defender:** Agregar carpeta a exclusiones
- **Avast/Norton/McAfee:** Configurar excepciones
- **Firewall:** Permitir conexiones salientes

#### **3. Modo Compatibilidad**
1. Clic derecho en `smart_seller.exe`
2. Propiedades → Compatibilidad
3. "Ejecutar este programa en modo de compatibilidad"
4. Seleccionar "Windows 8" o "Windows 7"

### 📋 **Checklist de Verificación:**

- [ ] Todos los archivos extraídos del ZIP
- [ ] Ejecutando como administrador
- [ ] Antivirus configurado con excepciones
- [ ] .NET Framework instalado
- [ ] Visual C++ Redistributable instalado
- [ ] Windows actualizado
- [ ] Drivers de gráficos actualizados
- [ ] Espacio suficiente en disco
- [ ] Permisos de carpeta correctos

### 🆘 **Contacto de Soporte:**

Si el problema persiste, proporcionar:
1. Captura de pantalla del error
2. Información del sistema
3. Logs de error (si existen)
4. Pasos exactos realizados

---

**Nota:** Esta aplicación requiere Windows 10 o superior y puede tener problemas en sistemas muy antiguos o con configuraciones de seguridad muy restrictivas.
