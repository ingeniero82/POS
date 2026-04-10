; Script de Inno Setup para Smart Seller POS
; 1) Generar Release: desde SmartSeller_POS_v1.0_DNPA ejecutar flutter build windows --release.
;    El proyecto genera smart_seller_dev.exe; este script instala smart_seller.exe (renombrado) automáticamente.
;    compilar_windows.bat sigue siendo útil para probar la carpeta Release localmente con smart_seller.exe.
; 2) La salida puede estar en build\... o build_spos\... según flutter config --build-dir.
; 3) Abrir Inno Setup -> File -> Open -> este .iss -> Build -> Compile (F9). Salida: ..\output\
; Inno Setup (gratis): https://jrsoftware.org/isinfo.php

; Carpeta Release: prioridad build_spos (debug/build recomendado en el proyecto) luego build.
#if DirExists(AddBackslash(SourcePath) + "..\build_spos\windows\x64\runner\Release")
  #define ReleaseFolder "..\build_spos\windows\x64\runner\Release"
#elif DirExists(AddBackslash(SourcePath) + "..\build\windows\x64\runner\Release")
  #define ReleaseFolder "..\build\windows\x64\runner\Release"
#else
  #error No existe carpeta Release. Ejecute flutter build windows --release desde SmartSeller_POS_v1.0_DNPA. Revise build_spos o build segun flutter config --build-dir.
#endif

#define MyAppName "Smart Seller POS"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Losoft"
#define MyAppExeName "smart_seller.exe"
#define MyAppAssocName "Smart Seller"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\SmartSellerPOS
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Carpeta de salida del instalador (al compilar)
OutputDir=..\output
OutputBaseFilename=SmartSeller_POS_Setup_v{#MyAppVersion}
SetupIconFile=
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear icono en el escritorio"; GroupDescription: "Iconos adicionales:"; Flags: unchecked
Name: "quicklaunchicon"; Description: "Crear icono en la barra de tareas"; GroupDescription: "Iconos adicionales:"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Flutter/CMake usa BINARY_NAME smart_seller_dev.exe; accesos directos y [Run] esperan smart_seller.exe.
#if FileExists(AddBackslash(SourcePath) + ReleaseFolder + "\smart_seller_dev.exe")
Source: "{#ReleaseFolder}\smart_seller_dev.exe"; DestDir: "{app}"; DestName: "smart_seller.exe"; Flags: ignoreversion
#endif
; Copiar el resto (dlls, data, etc.); no incluir el .dev en destino si ya instalamos smart_seller.exe arriba
Source: "{#ReleaseFolder}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "smart_seller_dev.exe"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Ejecutar {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: dirifempty; Name: "{app}"

[Code]
// La base de datos (smart_seller.db) está en Documentos del usuario.
// El desinstalador NO borra Documentos; los datos del cliente se conservan.
