; Script de Inno Setup para Smart Seller POS
; Necesitas instalar Inno Setup (gratis): https://jrsoftware.org/isinfo.php
; Luego: compila este archivo .iss y obtendrás SmartSeller_Setup.exe

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
; Copiar todo el contenido de la carpeta Release (exe, dlls, data)
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

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
