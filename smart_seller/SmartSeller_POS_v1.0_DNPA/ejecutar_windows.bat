@echo off
REM Ejecutar Smart Seller solo en Windows (no usa Android ni Gradle)
cd /d "%~dp0"
flutter run -d windows
pause
