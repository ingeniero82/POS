# Proceso para probar licencia normal y licencia DEMO

## Antes de empezar: “empezar sin licencia”

Para simular un equipo sin activar tienes dos opciones:

**Opción A – Borrar datos de la app (recomendada en desarrollo)**  
- Cierra Smart Seller si está abierto.  
- Borra la carpeta de datos de la app en Windows (donde se guarda la licencia):
  - Ejemplo típico: `%LOCALAPPDATA%\smart_seller` o la ruta que use tu app.
  - Si no encuentras la carpeta, en la app en depuración suele estar en la carpeta del proyecto/build.
- O desinstala y vuelve a instalar (en instalación real).

**Opción B – Ejecutar sin tener activado**  
- Si es la primera vez que corres la app en ese equipo, ya empezarás en la pantalla de activación.

---

## Caso 1: Probar LICENCIA NORMAL (clave atada al equipo)

### 1. Abrir la app sin licencia

1. Ejecuta Smart Seller (o `flutter run` desde `SmartSeller_POS_v1.0_DNPA`).
2. Debe aparecer la **pantalla de activación** (ID de equipo + campo de clave).

### 2. Obtener el ID de este equipo

1. En esa pantalla verás algo como: **ID de este equipo (envíelo al proveedor...)**.
2. Copia el ID (o anótalo). Ejemplo: `A1B2C3D4E5F67890`.

### 3. Generar la clave para este equipo (keygen)

1. Abre una terminal en la carpeta del keygen:
   ```bash
   cd SmartSeller_POS_v1.0_DNPA\keygen
   ```
2. Genera la clave pasando **exactamente** el ID que copiaste:
   ```bash
   dart run keygen A1B2C3D4E5F67890
   ```
   (sustituye por tu ID real.)
3. La consola mostrará algo como: `Clave para este equipo:` y una línea con la clave.

### 4. Activar en la app

1. Pega esa clave en el campo **Clave de activación**.
2. Pulsa **Activar**.
3. Debe llevarte al **login** (usuario/contraseña).

### 5. Comprobar que es licencia normal

1. Inicia sesión y entra al **Dashboard**.
2. **No** debe aparecer la barra amarilla “Modo demostración”.
3. El programa funciona normal; la licencia queda atada a este PC.

### 6. (Opcional) Comprobar que la clave no vale en otro “equipo”

- Si tuvieras otro PC (o otra carpeta de datos que simule otro equipo), al usar la **misma** clave en ese otro “equipo” no debería activar, porque la licencia normal es solo para el ID del primer equipo.

---

## Caso 2: Probar LICENCIA DEMO (clave que vale en cualquier equipo + aviso)

### 1. Volver a “sin licencia” (para repetir la prueba)

- Borra la carpeta de datos de la app (o desinstala/reinstala) para que al abrir de nuevo aparezca la **pantalla de activación**.

### 2. Generar la clave DEMO (keygen)

1. En la carpeta del keygen:
   ```bash
   cd SmartSeller_POS_v1.0_DNPA\keygen
   ```
2. Ejecuta:
   ```bash
   dart run keygen --demo
   ```
3. La consola mostrará algo como:  
   `Clave DEMO (válida en cualquier equipo, para muestras en local):`  
   y una línea con la clave.

### 3. Activar en la app con la clave DEMO

1. Abre Smart Seller (pantalla de activación).
2. Pega la **clave DEMO** en el campo de clave.
3. Pulsa **Activar**.
4. Debe llevarte al **login**.

### 4. Comprobar el aviso “Modo demostración”

1. Inicia sesión y entra al **Dashboard**.
2. **Debe** aparecer la **barra amarilla** arriba con el texto:
   - *"Modo demostración — Solo para muestras. No es licencia de producción."*
3. Esa barra debe verse también al entrar a **Punto de venta**, **Inventario**, etc. (todo lo que se abre desde el Dashboard).
4. El programa funciona igual; la diferencia es el aviso y que esta clave valdría en cualquier PC.

### 5. (Opcional) Comprobar que la clave DEMO vale en “cualquier equipo”

- En otro PC (o otra instalación/datos), activa con la **misma** clave DEMO: debe activar y mostrar el mismo aviso “Modo demostración”. La licencia normal no haría eso.

---

## Resumen rápido

| Qué probar        | Keygen                    | En la app                         | Qué verás                          |
|-------------------|---------------------------|-----------------------------------|------------------------------------|
| **Licencia normal** | `dart run keygen <ID>`    | Pegar clave → Activar             | Login → sin barra “Modo demostración” |
| **Licencia DEMO**   | `dart run keygen --demo`  | Pegar clave DEMO → Activar       | Login → barra amarilla “Modo demostración” |

---

## Dónde está el keygen

- Carpeta: `SmartSeller_POS_v1.0_DNPA\keygen`
- Comandos:
  - Clave para un equipo: `dart run keygen <ID_DE_EQUIPO>`
  - Clave demo: `dart run keygen --demo`

Si algo no coincide (por ejemplo no ves la barra en demo o la ves en normal), revisa que hayas usado la clave correcta en cada caso y que hayas borrado datos/reinstalado entre un caso y otro para no arrastrar una activación anterior.

---

## Reseteo rápido: volver a pantalla de activación

Para probar el otro caso (normal ↔ demo) necesitas que la app pida activación de nuevo:

1. Cierra Smart Seller.
2. En Windows, la licencia se guarda con SharedPreferences. Suele estar en:
   - `%APPDATA%\com.example\smart_seller` o
   - Una carpeta con el nombre del proyecto dentro de `%LOCALAPPDATA%` o `%APPDATA%`.
3. Borra esa carpeta (o solo el archivo donde se guardan las preferencias, si lo identificas).
4. Abre de nuevo la app: aparecerá la pantalla de activación.

Si ejecutas con `flutter run`, a veces los datos están en la carpeta `build` del proyecto; si usas el instalador, en AppData. Desinstalar y volver a instalar también deja la app “sin licencia”.
