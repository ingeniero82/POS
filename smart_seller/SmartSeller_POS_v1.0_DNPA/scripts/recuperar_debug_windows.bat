@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0.."

echo.
echo ============================================================
echo  Smart Seller POS - Recuperar entorno debug Windows
echo ============================================================
echo.

echo [1/4] Intentando cerrar procesos que bloquean DLL...
taskkill /F /IM smart_seller.exe /T >nul 2>&1
taskkill /F /IM smart_seller_dev.exe /T >nul 2>&1
echo      Listo (si no habia procesos, es normal).
echo.

echo [2/4] Flutter: salida nativa en build_spos (evita locks en build\windows\...)
echo       y sin Android (no requiere SDK).
flutter config --build-dir=build_spos
if errorlevel 1 goto :err
flutter config --no-enable-android
if errorlevel 1 goto :err
echo.

echo [3/4] flutter pub get
flutter pub get
if errorlevel 1 goto :err
echo.

echo [4/4] Recordatorio
echo       - Depura con la config "SmartSeller POS (Windows)" en Cursor/VS Code.
echo       - Si CMake sigue con "Permission denied", reinicia el PC o mata el
echo         proceso desde el Administrador de tareas como administrador.
echo       - Guia completa: scripts\RECUPERAR_DEBUG_WINDOWS.txt
echo.
echo ============================================================
echo  OK. Prueba F5 o: flutter run -d windows
echo ============================================================
goto :eof

:err
echo.
echo ERROR: Revisa que Flutter este en el PATH y ejecutes este .bat desde el proyecto.
exit /b 1
