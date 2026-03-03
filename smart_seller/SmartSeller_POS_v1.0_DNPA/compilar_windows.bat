@echo off
REM Compilar ejecutable solo para Windows
cd /d "%~dp0"
flutter clean
flutter pub get
flutter build windows --release
echo.
echo Listo. Ejecutable en: build\windows\x64\runner\Release\smart_seller.exe
pause
