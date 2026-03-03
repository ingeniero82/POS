@echo off
title Smart Seller POS - Instalacion Basica
color 0B

echo.
echo ========================================
echo    SMART SELLER POS - INSTALACION BASICA
echo ========================================
echo.

echo Verificando archivos...
if not exist "smart_seller.exe" (
    echo ERROR: Archivo smart_seller.exe no encontrado
    echo Ejecute INSTALAR_COMPLETO.bat como administrador
    pause
    exit /b 1
)

echo Archivos verificados - OK

echo.
echo Configurando permisos...
icacls "smart_seller.exe" /grant Everyone:F >nul 2>&1
echo Permisos configurados

echo.
echo ========================================
echo    INSTALACION BASICA COMPLETADA
echo ========================================
echo.
echo Para iniciar la aplicacion, ejecute: smart_seller.exe
echo.

pause
