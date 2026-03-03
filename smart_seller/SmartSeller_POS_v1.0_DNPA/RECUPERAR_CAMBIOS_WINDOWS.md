# Recuperar cambios perdidos de Windows

Quedamos atrás: se perdió parte de los últimos cambios que solo estaban en Windows (algunos sin commit, otros revertidos con lo de Android). Esta guía sirve para ver qué tenías y cómo intentar recuperarlo.

---

## Lo que SÍ está en Git (commits que puedes recuperar)

| Commit | Descripción |
|--------|-------------|
| **b3d726f** | Roles y permisos: admin con todos los permisos, 5 roles, crear usuario con todos los roles, admin puede eliminar gerente, Datos empresa solo admin |
| **0fc3c4d** | POS: mejoras caja, impresora, formato pesos Colombia y reportes (incluye printer_config_screen, print_service, pos_screen, pos_controller, dashboard, login, main, sqlite, reports, accounting, etc.) |
| **b126374** | Formato de moneda colombiana en toda la app |
| **709d1f6** | Modo táctil con teclado virtual para POS |
| **4b61f00** | FIX: tecla N en modal de impresión |
| **67b9e25** | Ejecutable completo + scripts de instalación y troubleshooting |
| **76bca68** | Reportes PDF profesionales y mejora del cálculo de precios |
| **0322dde** | Rol de mantenimiento con permisos específicos |
| **b66b0ed** | Facturación electrónica completa |

El commit **0fc3c4d** es una “foto” muy completa del POS en Windows (impresora, formato pesos, reportes, printer_config, etc.). Si algo de eso se perdió, se puede traer de ese commit.

---

## Cómo ver qué había en un commit

En la carpeta del repo (por ejemplo `D:\losoft\DEMOV2`):

```powershell
# Ver lista de archivos que tocó un commit
git show 0fc3c4d --stat

# Ver el contenido de un archivo en ese commit (ej. main.dart)
git show 0fc3c4d:smart_seller/SmartSeller_POS_v1.0_DNPA/lib/main.dart

# Comparar un archivo actual con el de ese commit
git diff 0fc3c4d -- smart_seller/SmartSeller_POS_v1.0_DNPA/lib/main.dart
```

Así puedes ver exactamente qué tenía ese commit en cada archivo.

---

## Cómo recuperar archivos concretos de un commit

Para **un archivo** (sustituye RUTA por la ruta dentro del repo):

```powershell
git checkout 0fc3c4d -- smart_seller/SmartSeller_POS_v1.0_DNPA/lib/screens/printer_config_screen.dart
```

Para **toda la carpeta lib del POS** de ese commit (cuidado: pisa todo lo que tengas ahora):

```powershell
git checkout 0fc3c4d -- smart_seller/SmartSeller_POS_v1.0_DNPA/lib/
```

Hazlo solo si quieres volver atrás del todo en `lib/`; si no, usa `checkout` archivo por archivo.

---

## Lo que probablemente se perdió y NO está en Git

- **Formato adaptable del ticket** (ancho de papel, márgenes, columnas Cant/Descripción/P.Unit/Total, vista previa en Configuración de impresora). Lo habíamos vuelto a dejar en el código en una sesión anterior; si lo quitaste o revertiste, habría que reimplementarlo.
- Cualquier otro cambio que hayas hecho **solo en tu PC** y no hayas hecho commit.

---

## Qué hacer ahora

1. **Si quieres “volver” al estado del commit 0fc3c4d**  
   Usa `git show 0fc3c4d --stat` y luego `git checkout 0fc3c4d -- <archivo>` solo para los archivos que quieras recuperar (o toda `lib/` si aceptas perder cambios locales).

2. **Si quieres mantener licencia + arranque sin bloqueos**  
   No recuperes el `main.dart` de 0fc3c4d tal cual; mejor compara con `git diff 0fc3c4d -- smart_seller/SmartSeller_POS_v1.0_DNPA/lib/main.dart` y trae solo las partes que te interesen, dejando el flujo de licencia y el `Future.delayed` que evita el bloqueo.

3. **Si me dices qué echas en falta** (por ejemplo: “formato de ticket”, “pantalla de impresora”, “algo del POS”, “reportes”) puedo indicarte exactamente qué archivo(s) mirar y qué líneas o bloques recuperar de 0fc3c4d o de b3d726f.

Cuando sepas qué quieres recuperar (por nombre de pantalla o de cambio), dilo y lo vamos archivo por archivo.
