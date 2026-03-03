@echo off
title Preparar Instalador para Cliente
color 0B

echo.
echo ========================================
echo    PREPARAR INSTALADOR PARA CLIENTE
echo ========================================
echo.

set CLIENTE_DIR=D:\losoft\instalador cliente

echo [1/3] Creando instalador...
call "instalador\crear_instalador.bat"
if errorlevel 1 (
    echo ERROR: No se pudo crear el instalador
    pause
    exit /b 1
)

echo.
echo [2/3] Verificando que el instalador se creó...
if not exist "dist\SmartSellerPOS_Setup_v2.0.exe" (
    echo ERROR: El instalador no se creó correctamente
    pause
    exit /b 1
)
echo ✓ Instalador creado: dist\SmartSellerPOS_Setup_v2.0.exe

echo.
echo [3/3] Copiando instalador a carpeta del cliente...
if not exist "%CLIENTE_DIR%" (
    echo Creando carpeta del cliente...
    mkdir "%CLIENTE_DIR%"
)

copy /Y "dist\SmartSellerPOS_Setup_v2.0.exe" "%CLIENTE_DIR%\SmartSellerPOS_Setup_v2.0.exe"
if errorlevel 1 (
    echo ERROR: No se pudo copiar el instalador
    pause
    exit /b 1
)

echo ✓ Instalador copiado a: %CLIENTE_DIR%
echo.

echo ========================================
echo    PROCESO COMPLETADO
echo ========================================
echo.
echo El instalador está listo en:
echo %CLIENTE_DIR%\SmartSellerPOS_Setup_v2.0.exe
echo.
echo Archivos en la carpeta del cliente:
dir /B "%CLIENTE_DIR%"
echo.
echo Puede entregar toda la carpeta al cliente:
echo %CLIENTE_DIR%
echo.

pause


