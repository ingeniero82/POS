@echo off
cd /d "%~dp0"
start "Clave DEMO - Smart Seller" cmd /k "cd /d %~dp0. && echo. && echo Generando clave DEMO... && dart pub get && echo. && dart run keygen --demo && echo. && echo Cierra esta ventana cuando hayas copiado la clave. && pause"
