@echo off
echo ========================================
echo    Smart Seller POS - Instalacion
echo    Version 2.0 Final
echo ========================================
echo.

echo Verificando permisos de administrador...
net session >nul 2>&1
if %errorLevel% == 0 (
    echo ✓ Permisos de administrador confirmados
) else (
    echo ❌ ERROR: Este programa requiere permisos de administrador
    echo.
    echo Por favor:
    echo 1. Clic derecho en este archivo
    echo 2. Seleccionar "Ejecutar como administrador"
    echo.
    pause
    exit /b 1
)

echo.
echo Iniciando instalacion...
echo.

echo [1/5] Verificando dependencias del sistema...
where /q dotnet
if %errorLevel% == 0 (
    echo ✓ .NET Framework detectado
) else (
    echo ⚠️  Advertencia: .NET Framework no detectado
    echo    El programa puede funcionar, pero se recomienda instalarlo
)

echo.
echo [2/5] Creando directorio de instalacion...
if not exist "C:\SmartSellerPOS" mkdir "C:\SmartSellerPOS"
if not exist "C:\SmartSellerPOS\Data" mkdir "C:\SmartSellerPOS\Data"
echo ✓ Directorio creado: C:\SmartSellerPOS

echo.
echo [3/5] Copiando archivos del programa...
copy "smart_seller.exe" "C:\SmartSellerPOS\" /Y >nul
copy "flutter_windows.dll" "C:\SmartSellerPOS\" /Y >nul
copy "sqlite3.dll" "C:\SmartSellerPOS\" /Y >nul
copy "sqlite3_flutter_libs_plugin.dll" "C:\SmartSellerPOS\" /Y >nul
copy "icudtl.dat" "C:\SmartSellerPOS\" /Y >nul
xcopy "flutter_assets" "C:\SmartSellerPOS\flutter_assets\" /E /I /Y >nul
echo ✓ Archivos copiados correctamente

echo.
echo [4/5] Configurando acceso rapido...
echo [InternetShortcut] > "%USERPROFILE%\Desktop\Smart Seller POS.url"
echo URL=file:///C:/SmartSellerPOS/smart_seller.exe >> "%USERPROFILE%\Desktop\Smart Seller POS.url"
echo IconFile=C:\SmartSellerPOS\smart_seller.exe >> "%USERPROFILE%\Desktop\Smart Seller POS.url"
echo IconIndex=0 >> "%USERPROFILE%\Desktop\Smart Seller POS.url"
echo ✓ Acceso directo creado en el escritorio

echo.
echo [5/5] Configurando permisos de base de datos...
icacls "C:\SmartSellerPOS" /grant "%USERNAME%":F /T >nul 2>&1
echo ✓ Permisos configurados

echo.
echo ========================================
echo    INSTALACION COMPLETADA EXITOSAMENTE
echo ========================================
echo.
echo El programa se ha instalado en:
echo C:\SmartSellerPOS\
echo.
echo Acceso directo creado en el escritorio
echo.
echo Credenciales por defecto:
echo Usuario: admin
echo Contraseña: 123456
echo.
echo ⚠️  IMPORTANTE: Cambiar la contraseña en la primera sesion
echo.
echo Presiona cualquier tecla para abrir el programa...
pause >nul

echo.
echo Abriendo Smart Seller POS...
start "" "C:\SmartSellerPOS\smart_seller.exe"

echo.
echo Instalacion finalizada. ¡Gracias por usar Smart Seller POS!
pause
