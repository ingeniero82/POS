@echo off
title Crear Instalador Smart Seller POS
color 0B

echo.
echo ========================================
echo    CREAR INSTALADOR SMART SELLER POS
echo ========================================
echo.

REM Verificar que Inno Setup esté instalado
set INNO_SETUP_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
if not exist "%INNO_SETUP_PATH%" (
    set INNO_SETUP_PATH=C:\Program Files\Inno Setup 6\ISCC.exe
    if not exist "%INNO_SETUP_PATH%" (
        echo ERROR: Inno Setup no encontrado
        echo.
        echo Por favor instale Inno Setup desde:
        echo https://jrsoftware.org/isdl.php
        echo.
        echo O especifique la ruta manualmente editando este archivo.
        pause
        exit /b 1
    )
)

echo [1/5] Verificando compilación de Flutter...
call "instalador\verificar_archivos.bat"
if errorlevel 1 (
    echo.
    echo ADVERTENCIA: No se encontraron todos los archivos necesarios.
    echo Compilando aplicación...
    echo.
    flutter clean
    flutter pub get
    flutter build windows --release
    if errorlevel 1 (
        echo ERROR: La compilación falló
        pause
        exit /b 1
    )
    echo.
    echo Verificando archivos nuevamente...
    call "instalador\verificar_archivos.bat"
    if errorlevel 1 (
        echo ERROR: Aún faltan archivos después de compilar
        pause
        exit /b 1
    )
)

echo [2/5] Verificando archivos necesarios...
if not exist "build\windows\x64\runner\Release\smart_seller.exe" (
    echo ERROR: smart_seller.exe no encontrado
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

echo [3/5] Listando todos los DLLs que se incluirán...
for %%f in ("build\windows\x64\runner\Release\*.dll") do (
    echo   - %%~nxf
)

echo [4/5] Creando directorio de distribución...
if not exist "dist" mkdir "dist"

echo [5/5] Compilando instalador con Inno Setup...
"%INNO_SETUP_PATH%" "instalador\SmartSellerPOS_Installer.iss"

if errorlevel 1 (
    echo.
    echo ERROR: La compilación del instalador falló
    pause
    exit /b 1
)

echo.
echo ========================================
echo    INSTALADOR CREADO EXITOSAMENTE
echo ========================================
echo.
echo El instalador se encuentra en: dist\SmartSellerPOS_Setup_v2.0.exe
echo.
echo Puede distribuir este archivo a sus clientes.
echo.

pause

