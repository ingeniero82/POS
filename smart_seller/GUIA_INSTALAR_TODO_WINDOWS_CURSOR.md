# Guía: Instalar todo en Windows y usar Cursor con Smart Seller

Después de restaurar Windows, sigue estos pasos en orden para tener Flutter, el proyecto y Cursor funcionando de nuevo.

---

## 1. Instalar Git (si no lo tienes)

1. Descarga: https://git-scm.com/download/win  
2. Instala con opciones por defecto.  
3. Abre **PowerShell** o **CMD** y verifica:
   ```bash
   git --version
   ```

---

## 2. Instalar Flutter en Windows

1. Descarga el SDK de Flutter para Windows:  
   https://docs.flutter.dev/get-started/install/windows  
   (o directo: https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip — comprueba la versión estable actual en la web).

2. Descomprime en una ruta **corta y sin espacios**, por ejemplo:
   - `C:\dev\flutter`  
   Evita rutas como `C:\Users\TuUsuario\Documents\...` si son muy largas.

3. Añadir Flutter al PATH:
   - Busca “Variables de entorno” en Windows.
   - En “Variables del sistema” edita **Path**.
   - Añade la ruta hasta la carpeta **flutter** (ej: `C:\dev\flutter`).
   - Acepta todo y cierra.

4. Abre una **nueva** PowerShell o CMD y ejecuta:
   ```bash
   flutter --version
   flutter doctor
   ```
   Si falta algo (Android SDK, Visual Studio, etc.), `flutter doctor` te lo dirá. Para **solo Windows desktop** suele bastar con instalar **Visual Studio** (con workload “Desarrollo para el escritorio con C++”).

5. Aceptar licencias (si pide):
   ```bash
   flutter doctor --android-licenses
   ```
   (Solo necesario si vas a usar Android.)

---

## 3. Instalar Visual Studio (para compilar en Windows)

Necesario para ejecutar la app en Windows (escritorio).

1. Descarga **Visual Studio Community**:  
   https://visualstudio.microsoft.com/es/downloads/

2. En el instalador, marca el workload:
   - **“Desarrollo para el escritorio con C++”**  
   y asegúrate de que esté incluido el **Windows 10/11 SDK**.

3. Instala y reinicia si lo pide.

4. Verifica:
   ```bash
   flutter doctor -v
   ```
   Debe aparecer una marca verde en “Windows Version” y en “Visual Studio”.

---

## 4. Instalar Cursor

1. Descarga Cursor: https://cursor.com (o desde la web oficial).

2. Instala y abre Cursor.

3. Instala la extensión de **Flutter** (y Dart) dentro de Cursor:
   - `Ctrl+Shift+X` para abrir extensiones.
   - Busca **“Flutter”** (publicada por Dart Code / Flutter Team).
   - Instala **Flutter** (suele incluir Dart).

4. Reinicia Cursor si lo pide.

---

## 5. Abrir el proyecto y restaurar dependencias

1. En Cursor: **File → Open Folder** (o “Abrir carpeta”).

2. Elige la carpeta del **proyecto Flutter**:
   - Para este proyecto: la carpeta que contiene `pubspec.yaml`.
   - Ejemplo: `D:\losoft\DEMOV2\smart_seller`  
   (no abras solo `DEMOV2` si el `pubspec.yaml` está dentro de `smart_seller`).

3. En la terminal integrada de Cursor (`Ctrl+ñ` o View → Terminal), entra a esa carpeta y ejecuta:
   ```bash
   cd D:\losoft\DEMOV2\smart_seller
   flutter pub get
   ```
   (Ajusta la ruta si tu proyecto está en otro disco o carpeta.)

4. Si el proyecto está en Git y quieres asegurarte de estar en el commit correcto:
   ```bash
   cd D:\losoft\DEMOV2
   git status
   git log -1 --oneline
   ```

---

## 6. Ejecutar la app en Windows

1. En Cursor, con el proyecto abierto, abre la terminal en la carpeta del proyecto (donde está `pubspec.yaml`).

2. Lista dispositivos:
   ```bash
   flutter devices
   ```
   Debe aparecer **windows** (desktop).

3. Ejecuta la app:
   ```bash
   flutter run -d windows
   ```
   O en Cursor: **Run → Start Debugging** (F5) y elige el dispositivo **Windows** si te lo pide.

4. La primera vez puede tardar más (compilación). Las siguientes serán más rápidas.

---

## 7. Si algo falla

- **“flutter no se reconoce”**  
  PATH no está bien. Repite el paso 2.3 (añadir `C:\dev\flutter` o tu ruta) y abre una **nueva** terminal.

- **“No device found” o error de Visual Studio**  
  Ejecuta `flutter doctor -v` y corrige lo que marque en rojo (sobre todo Visual Studio y Windows SDK).

- **Error de dependencias**  
  En la carpeta del proyecto:
  ```bash
  flutter clean
  flutter pub get
  flutter run -d windows
  ```

- **Base de datos o app se cuelga**  
  La app guarda la BD en la carpeta de documentos del usuario. Si quieres empezar de cero (solo datos de prueba), puedes renombrar o borrar `smart_seller.db` en esa carpeta (suele ser `C:\Users\TuUsuario\Documents` o similar, según `path_provider`).

---

## Resumen rápido (después de tener todo instalado)

```text
1. Abrir Cursor → Open Folder → smart_seller (carpeta con pubspec.yaml)
2. Terminal: cd ruta\smart_seller
3. flutter pub get
4. flutter run -d windows
```

Guarda este archivo en el proyecto o en tu carpeta de documentación para no tener que recordar los pasos.
