@echo off
title Verificar Archivos para Instalador
color 0B

echo.
echo ========================================
echo    VERIFICACION DE ARCHIVOS COMPILADOS
echo ========================================
echo.

set RELEASE_PATH=build\windows\x64\runner\Release

echo Verificando carpeta de compilación...
if not exist "%RELEASE_PATH%" (
    echo.
    echo ERROR: No se encontró la carpeta de compilación
    echo Ruta esperada: %RELEASE_PATH%
    echo.
    echo Por favor, compile la aplicación primero:
    echo   flutter build windows --release
    echo.
    pause
    exit /b 1
)

echo ✓ Carpeta encontrada: %RELEASE_PATH%
echo.

echo Verificando archivos necesarios...
echo.

set ERROR_COUNT=0

if exist "%RELEASE_PATH%\smart_seller.exe" (
    echo ✓ smart_seller.exe
) else (
    echo ✗ smart_seller.exe - FALTANTE
    set /a ERROR_COUNT+=1
)

if exist "%RELEASE_PATH%\flutter_windows.dll" (
    echo ✓ flutter_windows.dll
) else (
    echo ✗ flutter_windows.dll - FALTANTE
    set /a ERROR_COUNT+=1
)

if exist "%RELEASE_PATH%\sqlite3.dll" (
    echo ✓ sqlite3.dll
) else (
    echo ✗ sqlite3.dll - FALTANTE
    set /a ERROR_COUNT+=1
)

if exist "%RELEASE_PATH%\sqlite3_flutter_libs_plugin.dll" (
    echo ✓ sqlite3_flutter_libs_plugin.dll
) else (
    echo ✗ sqlite3_flutter_libs_plugin.dll - FALTANTE
    set /a ERROR_COUNT+=1
)

if exist "%RELEASE_PATH%\data" (
    echo ✓ Carpeta data\
) else (
    echo ✗ Carpeta data\ - FALTANTE
    set /a ERROR_COUNT+=1
)

if exist "%RELEASE_PATH%\data\icudtl.dat" (
    echo ✓ data\icudtl.dat
) else (
    echo ✗ data\icudtl.dat - FALTANTE
    set /a ERROR_COUNT+=1
)

if exist "%RELEASE_PATH%\data\app.so" (
    echo ✓ data\app.so
) else (
    echo ✗ data\app.so - FALTANTE
    set /a ERROR_COUNT+=1
)

echo.
echo Verificando DLLs adicionales...
for %%f in ("%RELEASE_PATH%\*.dll") do (
    echo   ✓ %%~nxf
)

echo.
if %ERROR_COUNT% == 0 (
    echo ========================================
    echo    TODOS LOS ARCHIVOS ESTAN PRESENTES
    echo ========================================
    echo.
    echo Puede proceder a crear el instalador.
    echo Ejecute: crear_instalador.bat
) else (
    echo ========================================
    echo    ERROR: FALTAN %ERROR_COUNT% ARCHIVO(S)
    echo ========================================
    echo.
    echo Por favor, compile la aplicación primero:
    echo   flutter clean
    echo   flutter pub get
    echo   flutter build windows --release
)

echo.
pause


