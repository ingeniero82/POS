# Cómo guardar todo el trabajo en el repositorio (respaldo)

Así no pierdes el trabajo si se daña el disco. El proyecto ya está en un repo Git; solo falta configurar tu identidad (una vez), hacer commit y subir.

## 1. Configurar tu identidad en Git (solo la primera vez)

Abre **PowerShell** o **CMD** y ejecuta (cambia nombre y correo por los tuyos):

```bash
git config --global user.email "tu@email.com"
git config --global user.name "Tu Nombre"
```

Ejemplo:
```bash
git config --global user.email "ingeniero@miempresa.com"
git config --global user.name "Ingeniero"
```

## 2. Hacer commit y subir al remoto

Desde la carpeta del repo (por ejemplo `D:\losoft\DEMOV2`):

```bash
cd D:\losoft\DEMOV2

# Ver qué hay pendiente
git status

# Añadir todo el proyecto POS (si no lo has hecho)
git add smart_seller/SmartSeller_POS_v1.0_DNPA/

# Crear el commit con todo lo guardado
git commit -m "POS: mejoras caja, impresora, formato pesos Colombia y reportes"

# Subir a GitHub/GitLab (tu remoto ya está como 'origin')
git push origin feature/facturacion-electronica-completa
```

Si tu rama principal es otra (por ejemplo `main`), usa:

```bash
git push origin main
```

## 3. Si aún no tienes repositorio en la nube

- **GitHub:** crea una cuenta en https://github.com, crea un repositorio nuevo y luego:
  ```bash
  git remote add origin https://github.com/TU_USUARIO/TU_REPO.git
  git push -u origin feature/facturacion-electronica-completa
  ```
- **GitLab:** igual en https://gitlab.com.

## 4. Respaldo periódico

Cada vez que hagas cambios importantes:

```bash
cd D:\losoft\DEMOV2
git add smart_seller/SmartSeller_POS_v1.0_DNPA/
git commit -m "Descripción breve de lo que cambiaste"
git push origin feature/facturacion-electronica-completa
```

Así tu código queda guardado en la nube y puedes recuperarlo desde otro PC o si cambias de disco.
