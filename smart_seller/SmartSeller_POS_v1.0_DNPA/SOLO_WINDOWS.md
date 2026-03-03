# Proyecto solo Windows (como antes de añadir Android)

La carpeta **android** se eliminó. El proyecto queda solo para **Windows**, como estaba antes.

## Ejecutar la app (desarrollo)
- Doble clic en **`ejecutar_windows.bat`**  
  o en terminal: `flutter run -d windows`

## Compilar ejecutable (release)
- Doble clic en **`compilar_windows.bat`**  
  o en terminal: `flutter build windows --release`  
- El .exe queda en: `build\windows\x64\runner\Release\smart_seller.exe`

## Instalador
Después de compilar, abre con Inno Setup el archivo `installer\SmartSeller_Setup.iss` y pulsa F9.

Al no existir la carpeta android, `flutter run` usará solo Windows (ya no hace falta `-d windows` ni tener Android SDK).
