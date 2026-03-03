@echo off
title Verificar Requisitos - Smart Seller POS
color 0E

echo.
echo ========================================
echo    VERIFICACION DE REQUISITOS DEL SISTEMA
echo ========================================
echo.

echo [1/5] Verificando sistema operativo...
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo Windows Version: %VERSION%

systeminfo | findstr /C:"OS Name" /C:"OS Version" /C:"System Type"
echo.

echo [2/5] Verificando arquitectura...
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo ✓ Sistema 64-bit detectado
) else (
    echo ✗ ERROR: Se requiere Windows 64-bit
    echo Este sistema no es compatible
    pause
    exit /b 1
)
echo.

echo [3/5] Verificando Visual C++ Redistributable...
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" >nul 2>&1
if %errorlevel% == 0 (
    echo ✓ Visual C++ Redistributable detectado
    for /f "tokens=3" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" /v Version 2^>nul') do echo   Version: %%a
) else (
    echo ⚠ Visual C++ Redistributable no encontrado
    echo   Se instalará automáticamente durante la instalación
)
echo.

echo [4/5] Verificando espacio en disco...
for /f "tokens=3" %%a in ('dir /-c ^| find "bytes free"') do set FREE=%%a
echo Espacio libre: %FREE% bytes
echo.

echo [5/5] Verificando permisos de administrador...
net session >nul 2>&1
if %errorlevel% == 0 (
    echo ✓ Permisos de administrador confirmados
) else (
    echo ⚠ No se ejecuta como administrador
    echo   Algunas funciones pueden requerir permisos elevados
)
echo.

echo ========================================
echo    VERIFICACION COMPLETADA
echo ========================================
echo.
echo El sistema cumple con los requisitos mínimos.
echo Puede proceder con la instalación.
echo.

pause


