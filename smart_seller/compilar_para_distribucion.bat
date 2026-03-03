@echo off
title Compilar Smart Seller POS para Distribución
color 0B

echo.
echo ========================================
echo    COMPILAR PARA DISTRIBUCIÓN
echo    Smart Seller POS v2.0
echo ========================================
echo.

REM Cambiar al directorio del proyecto
cd /d "%~dp0"

echo [PASO 1/6] Verificando Flutter...
where flutter >nul 2>&1
if errorlevel 1 (
    echo ERROR: Flutter no está en el PATH
    echo Por favor, instale Flutter y agregue al PATH
    pause
    exit /b 1
)
flutter --version
echo.

echo [PASO 2/6] Cerrando procesos que puedan bloquear archivos...
taskkill /F /IM smart_seller.exe >nul 2>&1
taskkill /F /IM dart.exe >nul 2>&1
timeout /t 2 >nul
echo OK - Procesos cerrados
echo.

echo [PASO 3/6] Limpiando compilaciones anteriores...
if exist "build" (
    echo Limpiando carpeta build...
    rmdir /s /q "build" 2>nul
)
flutter clean
echo OK - Limpieza completada
echo.

echo [PASO 4/6] Obteniendo dependencias...
flutter pub get
if errorlevel 1 (
    echo ERROR: No se pudieron obtener las dependencias
    pause
    exit /b 1
)
echo OK - Dependencias obtenidas
echo.

echo [PASO 5/6] Compilando aplicación (esto puede tardar varios minutos)...
echo Por favor, espere...
flutter build windows --release
if errorlevel 1 (
    echo.
    echo ERROR: La compilación falló
    echo.
    echo Posibles soluciones:
    echo 1. Verificar que Visual Studio esté instalado con "Desktop development with C++"
    echo 2. Ejecutar: flutter doctor -v
    echo 3. Verificar que no haya procesos bloqueando archivos
    echo.
    pause
    exit /b 1
)
echo OK - Compilación exitosa
echo.

echo [PASO 6/6] Verificando archivos generados...
if not exist "build\windows\x64\runner\Release\smart_seller.exe" (
    echo ERROR: El ejecutable no se generó correctamente
    pause
    exit /b 1
)

if not exist "build\windows\x64\runner\Release\flutter_windows.dll" (
    echo ERROR: flutter_windows.dll no encontrado
    pause
    exit /b 1
)

if not exist "build\windows\x64\runner\Release\data" (
    echo ERROR: Carpeta data no encontrada
    pause
    exit /b 1
)

echo.
echo ========================================
echo    COMPILACIÓN EXITOSA
echo ========================================
echo.
echo Archivos generados en:
echo build\windows\x64\runner\Release\
echo.
echo Próximo paso: Ejecutar instalador\crear_instalador.bat
echo.
pause
