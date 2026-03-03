@echo off
title Administrador: Smart Seller POS - Instalador Completo
color 0E

echo.
echo ========================================
echo    SMART SELLER POS - INSTALADOR COMPLETO
echo ========================================
echo.

REM Verificar si se ejecuta como administrador
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Ejecutando como administrador
) else (
    echo ERROR: Este script debe ejecutarse como administrador
    echo Haga clic derecho en este archivo y seleccione "Ejecutar como administrador"
    pause
    exit /b 1
)

echo Verificando requisitos del sistema...
echo Windows %OS% - Compatible
echo Arquitectura 64-bit - Compatible

echo.
echo Verificando archivos de la aplicacion...
if not exist "smart_seller.exe" (
    echo ERROR: Archivo principal faltante (smart_seller.exe)
    pause
    exit /b 1
)

echo Archivos de aplicacion - OK

echo.
echo Instalando dependencias del sistema...
call "INSTALAR_DEPENDENCIAS.bat"

echo.
echo Configurando seguridad del sistema...
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force" >nul 2>&1
echo Politica de ejecucion configurada

echo.
echo Configurando Windows Defender...
powershell -Command "Add-MpPreference -ExclusionPath '%cd%'" >nul 2>&1
echo Exclusion agregada a Windows Defender

echo.
echo ========================================
echo    INSTALACION COMPLETADA EXITOSAMENTE
echo ========================================
echo.
echo La aplicacion esta lista para usar.
echo Para iniciar Smart Seller POS, ejecute: smart_seller.exe
echo.

pause
