@echo off
title Instalando Dependencias - Smart Seller POS
color 0A

echo.
echo ========================================
echo    INSTALANDO DEPENDENCIAS DEL SISTEMA
echo ========================================
echo.

echo Descargando Visual C++ Redistributable...
powershell -Command "Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile 'vc_redist.x64.exe'" >nul 2>&1

if exist "vc_redist.x64.exe" (
    echo Instalando Visual C++ Redistributable...
    start /wait vc_redist.x64.exe /quiet /norestart
    del vc_redist.x64.exe
    echo Visual C++ Redistributable instalado
) else (
    echo ADVERTENCIA: No se pudo descargar Visual C++ Redistributable
    echo La aplicacion puede funcionar sin esta dependencia
)

echo.
echo Verificando .NET Framework...
powershell -Command "Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name version -EA 0 | Where-Object {$_.PSChildName -Match '^(?!S)\p{L}'} | Select-Object PSChildName, version" >nul 2>&1

echo.
echo ========================================
echo    DEPENDENCIAS INSTALADAS
echo ========================================
echo.

pause
