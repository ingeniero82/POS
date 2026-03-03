# Script para instalar Flutter SDK en Windows (manual, porque winget no lo tiene)
# Ejecutar en PowerShell COMO ADMINISTRADOR

$FlutterVersion = "3.24.5"
$FlutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$FlutterVersion-stable.zip"
$Destino = "C:\flutter"
$ZipPath = "$env:TEMP\flutter_windows.zip"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Instalador Flutter para Smart Seller  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Crear carpeta si no existe
if (-not (Test-Path "C:\")) {
    Write-Host "Error: No se puede usar C:\. Elige otra ruta y edita este script." -ForegroundColor Red
    exit 1
}

if (Test-Path $Destino) {
    Write-Host "Ya existe la carpeta $Destino." -ForegroundColor Yellow
    $resp = Read-Host "¿Sobrescribir? (s/n)"
    if ($resp -ne "s") { exit 0 }
    Remove-Item -Recurse -Force $Destino
}

Write-Host "1. Descargando Flutter $FlutterVersion (puede tardar varios minutos)..." -ForegroundColor Green
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $FlutterUrl -OutFile $ZipPath -UseBasicParsing
} catch {
    Write-Host "Error al descargar. Prueba descargar manualmente desde:" -ForegroundColor Red
    Write-Host "https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
    exit 1
}

Write-Host "2. Descomprimiendo en $Destino ..." -ForegroundColor Green
Expand-Archive -Path $ZipPath -DestinationPath "C:\" -Force
Remove-Item $ZipPath -ErrorAction SilentlyContinue

# La carpeta descomprimida es C:\flutter
if (-not (Test-Path "$Destino\bin\flutter.bat")) {
    Write-Host "Error: No se encontró flutter.bat. Revisa que C:\flutter\bin exista." -ForegroundColor Red
    exit 1
}

Write-Host "3. Agregando Flutter al PATH del usuario..." -ForegroundColor Green
$BinPath = "$Destino\bin"
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$BinPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinPath", "User")
    Write-Host "   PATH actualizado. Debes CERRAR y volver a abrir la terminal (y Cursor)." -ForegroundColor Yellow
} else {
    Write-Host "   Flutter ya estaba en el PATH." -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Flutter instalado en: $Destino" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "SIGUIENTE PASO:" -ForegroundColor Cyan
Write-Host "  1. Cierra esta ventana de PowerShell." -ForegroundColor White
Write-Host "  2. Cierra Cursor por completo." -ForegroundColor White
Write-Host "  3. Abre Cursor de nuevo." -ForegroundColor White
Write-Host "  4. Abre la terminal y escribe: flutter doctor" -ForegroundColor White
Write-Host ""
