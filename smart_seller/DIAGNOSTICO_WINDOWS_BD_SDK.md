# Diagnóstico: Windows, disco, base de datos y SDK (Dart/patch)

## Si ves "error patch" o fallo al cargar SQLite en Windows

### 1. Error típico: `Failed to load dynamic library 'sqlite3.dll'` (código 126)
- **Causa:** En Windows, `sqflite_common_ffi` necesita `sqlite3.dll`. A veces no se encuentra o el antivirus la bloquea.
- **Qué hacer:**
  - Ejecutar la app desde **Debug** (F5) suele funcionar porque usa la caché de pub.
  - Si falla en **Release** o al abrir el .exe: copiar `sqlite3.dll` junto al ejecutable. La DLL suele estar en:
    - `C:\Users\TU_USUARIO\AppData\Local\Pub\Cache\hosted\pub.dartlang.org\sqflite_common_ffi-2.x.x\lib\src\windows\sqlite3.dll`
    - o dentro de la carpeta del paquete `sqlite3_flutter_libs`.
  - Añadir una excepción en el **antivirus** para la carpeta del proyecto y la carpeta donde está el .exe.

### 2. Disco / permisos
- **Ruta de la base de datos:** La app guarda `smart_seller.db` en la carpeta de documentos del usuario (path_provider).
  - En Windows suele ser: `C:\Users\INGENIERO\Documents` o similar.
- **Comprobar:** Espacio libre en disco (que no esté lleno C: o D:) y que el usuario tenga permisos de lectura/escritura en esa carpeta.
- **Ruta larga:** En Windows, rutas muy largas pueden dar problemas. Evitar proyectos en rutas con muchos niveles o caracteres raros.

### 3. Dart SDK / Flutter
- Ya comprobado: `flutter doctor -v` muestra Flutter y Dart OK.
- Si aparece un error concreto de "patch" del SDK: anotar el mensaje exacto y la versión de Dart (`dart --version`). A veces es un paquete nativo (sqflite, path_provider) y no el SDK en sí.

### 4. Base de datos corrupta o bloqueada
- Si la app se cuelga al iniciar, puede ser que `smart_seller.db` esté abierta por otra instancia o corrupta.
- Cerrar todas las ventanas de la app y volver a ejecutar.
- Como prueba (solo si puedes perder datos de prueba): renombrar o mover `smart_seller.db` y dejar que la app cree una nueva. Si así arranca, el problema era el archivo de BD.

### 5. Cómo obtener el error exacto
- Al iniciar, si falla la BD, la app muestra la pantalla roja "Error al iniciar" con el mensaje.
- En la **DEBUG CONSOLE** (al ejecutar con F5) aparecen líneas con `❌ Error base de datos:` y el stack trace.
- Copiar ese mensaje completo ayuda a saber si es: DLL, disco, permisos o BD dañada.

---
*Creado para retroceso de overflow y diagnóstico Windows/BD/SDK.*
