@echo off
REM Compilar ejecutable solo para Windows
cd /d "%~dp0"
flutter clean
flutter pub get
flutter build windows --release
set "REL="
if exist "build_spos\windows\x64\runner\Release\smart_seller_dev.exe" set "REL=build_spos\windows\x64\runner\Release"
if exist "build\windows\x64\runner\Release\smart_seller_dev.exe" set "REL=build\windows\x64\runner\Release"
if defined REL (
  copy /Y "%REL%\smart_seller_dev.exe" "%REL%\smart_seller.exe" >nul
  echo Copiado smart_seller.exe para instalador / accesos directos.
  echo.
  echo Listo. Ejecutables en: %REL%\
) else (
  echo ADVERTENCIA: No se encontro smart_seller_dev.exe en Release (build\ ni build_spos\).
  echo Comprueba "flutter config --list" ^(build-dir^) y vuelve a compilar.
)
echo   - smart_seller_dev.exe (principal)
echo   - smart_seller.exe (copia para instalador / accesos directos)
pause
