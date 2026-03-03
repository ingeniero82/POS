@echo off
title Preparar Carpeta Portatil para Cliente
color 0A

echo.
echo ========================================
echo    PREPARAR CARPETA PORTATIL
echo ========================================
echo.

cd /d "D:\losoft\DEMOV2\smart_seller"

echo [1/3] Verificando archivos compilados...
if not exist "build\windows\x64\runner\Release\smart_seller.exe" (
    echo.
    echo Los archivos no están compilados. Compilando ahora...
    flutter clean
    flutter pub get
    flutter build windows --release
    if errorlevel 1 (
        echo ERROR: No se pudo compilar
        pause
        exit /b 1
    )
)
echo OK - Archivos encontrados

echo.
echo [2/3] Creando carpeta portatil...
set CARPETA_CLIENTE=D:\losoft\instalador cliente
if exist "%CARPETA_CLIENTE%" rmdir /s /q "%CARPETA_CLIENTE%"
mkdir "%CARPETA_CLIENTE%"

echo.
echo [3/3] Copiando archivos...
xcopy /E /I /Y "build\windows\x64\runner\Release\*" "%CARPETA_CLIENTE%\" >nul

echo Copiando documentacion...
copy /Y "instalador\INSTRUCCIONES_CLIENTE.md" "%CARPETA_CLIENTE%\INSTRUCCIONES.md" >nul
copy /Y "SOLUCION_PROBLEMAS_EJECUTABLE.md" "%CARPETA_CLIENTE%\SOLUCION_PROBLEMAS.md" >nul

echo.
echo Creando script de inicio...
(
echo @echo off
echo title Smart Seller POS
echo cd /d "%%~dp0"
echo start smart_seller.exe
) > "%CARPETA_CLIENTE%\INICIAR_SMART_SELLER.bat"

echo.
echo Creando archivo LEEME...
(
echo ========================================
echo    SMART SELLER POS
echo ========================================
echo.
echo PARA INICIAR LA APLICACION:
echo.
echo Hacer doble clic en: INICIAR_SMART_SELLER.bat
echo.
echo O hacer doble clic directamente en: smart_seller.exe
echo.
echo ========================================
echo.
echo Si tiene problemas, ver: SOLUCION_PROBLEMAS.md
echo.
) > "%CARPETA_CLIENTE%\LEEME.txt"

echo.
echo ========================================
echo    LISTO - CARPETA PORTATIL CREADA
echo ========================================
echo.
echo La carpeta esta en:
echo %CARPETA_CLIENTE%
echo.
echo Solo copie y pegue esta carpeta en el equipo del cliente.
echo El cliente hace doble clic en INICIAR_SMART_SELLER.bat
echo.
pause


