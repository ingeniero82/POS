@echo off
cd /d "%~dp0"
start "Clave legal - Smart Seller" cmd /k "cd /d %~dp0 && echo. && echo === Clave legal para un equipo === && echo. && dart pub get && echo. && dart run keygen && echo. && echo Cuando haya copiado la clave, cierre esta ventana. && pause"
