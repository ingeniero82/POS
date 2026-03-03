# Generador de claves (keygen)

**Solo uso interno. No incluir ni distribuir con el instalador.**

## Cómo ejecutarlo

**No hay un archivo "dart run keygen" en la carpeta.** Es un **comando** que se escribe en la **terminal** (PowerShell o CMD):

1. Abre la **terminal**: en Windows, `Win + R`, escribe `cmd` o `powershell` y Enter; o en VS Code/Cursor abre la terminal integrada (Ctrl+ñ o Ver → Terminal).
2. Ve a la carpeta del keygen:
   ```bash
   cd ruta\SmartSeller_POS_v1.0_DNPA\keygen
   ```
   (sustituye `ruta` por la ruta real, por ejemplo `d:\losoft\DEMOV2\smart_seller`)
3. Ejecuta uno de estos comandos:
   - **Clave DEMO:** `dart run keygen --demo`
   - **Clave para un equipo:** `dart run keygen ID_DE_EQUIPO` (ejemplo: `dart run keygen A1B2C3D4E5F67890`)

**Alternativa:** en la carpeta `keygen` hay dos archivos `.bat`. Puedes darles **doble clic**:
- **GenerarClaveDEMO.bat** → genera la clave demo y muestra el resultado.
- **GenerarClaveEquipo.bat** → te pide el ID del equipo, genera la clave y la muestra.

---

## Dos tipos de clave

| Tipo | Uso | Comando | Dónde vale |
|------|-----|---------|------------|
| **Equipo** | Cliente que instala en su PC/local | `dart run keygen <ID_DE_EQUIPO>` | Solo en ese equipo |
| **DEMO** | Personas que muestran el programa en un local (muestras) | `dart run keygen --demo` | En cualquier PC |

## Clave para cliente (equipo fijo)

1. El cliente abre Smart Seller, ve la pantalla de activación y copia el **ID de equipo**.
2. Tú ejecutas: `dart run keygen <ID_DE_EQUIPO>`.
3. Le envías la clave; la pega en la app y pulsa Activar. Esa instalación queda atada a ese PC.

## Clave DEMO (muestras en local)

- Para quien va a **mostrar** el programa en un local (demo), sin que tengas que dar de alta cada equipo.
- Generas una sola clave demo: `dart run keygen --demo`.
- Esa misma clave la puede usar en **cualquier PC** (portátil del demo, PC del local, etc.).
- **Recomendación:** no les des los datos del local (empresa, productos, caja real). Que muestren con datos de prueba o vacíos. Así, si algún día instalan el programa en un equipo que quieran vender, el comprador recibe solo la app vacía, no tu negocio.

## Ejemplos

```bash
# Cliente te envía ID A1B2C3D4E5F67890
dart run keygen A1B2C3D4E5F67890

# Clave para demos (vale en cualquier equipo)
dart run keygen --demo
```
