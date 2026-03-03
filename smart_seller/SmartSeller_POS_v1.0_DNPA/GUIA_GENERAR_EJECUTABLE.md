# Guía paso a paso: generar el ejecutable (Windows)

## Requisitos previos

1. **Flutter** instalado y en el PATH. Verificar con:
   ```bash
   flutter doctor
   ```
   Debe aparecer al menos: Flutter, Windows toolchain (Visual Studio).

2. **Visual Studio** (2019 o superior) con:
   - Carga de trabajo: **Desktop development with C++**
   - Componente: **Windows 10/11 SDK**

---

## Pasos para generar el ejecutable

### 1. Abrir terminal en la carpeta del proyecto

Abre PowerShell o CMD y ve a la carpeta del proyecto:

```bash
cd "d:\losoft\DEMOV2\smart_seller\SmartSeller_POS_v1.0_DNPA"
```

(Ajusta la ruta si tu proyecto está en otra ubicación.)

### 2. Limpiar compilaciones anteriores (opcional pero recomendado)

```bash
flutter clean
```

### 3. Obtener dependencias

```bash
flutter pub get
```

### 4. Compilar en modo Release para Windows

```bash
flutter build windows --release
```

Espera a que termine (puede tardar varios minutos la primera vez).

### 5. Dónde está el ejecutable

Al terminar, el ejecutable y todo lo necesario estarán en:

```
SmartSeller_POS_v1.0_DNPA\build\windows\x64\runner\Release\
```

Ahí encontrarás: **smart_seller.exe**, **data\\**, **flutter_windows.dll** y demás DLL. Para usar el programa en otro PC, copia **toda la carpeta** Release, no solo el .exe.

---

## Opción rápida: usar el .bat

1. Doble clic en **compilar_windows.bat** (en la raíz de `SmartSeller_POS_v1.0_DNPA`).
2. Esperar a que termine.
3. El ejecutable queda en: `build\windows\x64\runner\Release\smart_seller.exe`

---

## Compilar con versión específica (opcional)

```bash
flutter build windows --release --build-name=1.0.0 --build-number=1
```

---

## Si algo falla

- **"flutter no se reconoce"** → Flutter no está en el PATH. Instala Flutter y añade su carpeta `bin` al PATH.
- **Error de Visual Studio / Windows SDK** → Ejecuta `flutter doctor -v` y sigue las instrucciones para configurar el toolchain de Windows.
- **Error de dependencias** → Ejecuta de nuevo `flutter clean` y `flutter pub get`, luego `flutter build windows --release`.
