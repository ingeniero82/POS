# Manual básico – Smart Seller POS

**Para que usted pueda usar el programa con confianza y depender menos del técnico.**

---

## 1. Instalación y primer arranque

### Qué necesita
- Windows 10 o 11 (64 bits).
- Al menos 4 GB de RAM (recomendado 8 GB).
- Unos 2 GB libres en disco.

### Pasos
1. Descomprima el archivo ZIP que le entregaron en una carpeta (por ejemplo: `C:\SmartSeller`).
2. No mueva ni borre archivos sueltos; use siempre la carpeta completa.
3. Para abrir el programa: doble clic en **smart_seller.exe**.
4. Si Windows pide permisos, acepte “Ejecutar como administrador” la primera vez.

Si el antivirus bloquea el programa, agregue la carpeta donde está instalado como excepción.

---

## 2. Entrar al sistema (inicio de sesión)

1. En la pantalla de inicio verá campos de **Usuario** y **Contraseña**.
2. La primera vez su técnico le habrá dado un usuario y contraseña (por ejemplo: **admin** / **123456**).
3. Escriba usuario y contraseña y pulse **Entrar** (o Enter).
4. **Recomendación:** pida al técnico que cambie la contraseña por defecto después de la primera entrada.

Si no recuerda la contraseña, solo el administrador o el técnico pueden restablecerla.

---

## 3. Pantalla principal (menú lateral)

Después de entrar verá el **menú lateral izquierdo** (morado). Desde ahí se accede a todo:

| Opción | Para qué sirve |
|--------|-----------------|
| **Dashboard** | Resumen y accesos rápidos. |
| **Punto de Venta** | Hacer ventas (cobrar). |
| **Inventario** | Ver, agregar y editar productos. |
| **Clientes** | Lista de clientes y datos. |
| **Proveedores** | Lista de proveedores. |
| **Cuentas por Cobrar** | Ver lo que le deben y lo que usted debe. |
| **Reportes** | Ventas, inventario, contabilidad. |
| **Recogidas de Efectivo** | Registrar salidas de efectivo de caja. |
| **Configuración** | Opciones generales del programa. |
| **Datos de Empresa** | Nombre, NIT, dirección, etc. (para facturas y tickets). |
| **Usuarios** | Crear y editar usuarios (solo administrador). |
| **Permisos** | Definir qué puede hacer cada tipo de usuario. |

No todos los usuarios ven todas las opciones; depende de los permisos que tenga asignados.

---

## 4. Cómo hacer una venta (Punto de Venta)

### Antes de vender: abrir caja
- La primera vez que entre al **Punto de Venta** en el día, el programa le pedirá **abrir caja**.
- Indique el monto inicial de efectivo que hay en caja y confirme.
- Sin abrir caja no podrá registrar ventas.

### Pasos para una venta
1. En el menú, pulse **Punto de Venta**.
2. **Buscar producto:** escriba el nombre o código del producto en el cuadro de búsqueda (arriba). Puede usar el lector de código de barras si lo tiene.
3. **Agregar al carrito:** seleccione el producto de la lista y pulse **Agregar**, o ajuste la cantidad y luego agregue.
4. **Productos por peso:** si el producto se vende por peso (ej. frutas, carne), use la sección de balanza (abajo), pese y use “Usar peso actual” para que se calcule el monto.
5. Repita para todos los ítems de la venta.
6. **Procesar venta:** pulse el botón **Procesar Venta** (o la tecla **F2**).
7. Elija **método de pago** (efectivo, tarjeta, etc.) y, si aplica, el monto recibido.
8. Confirme. El programa imprimirá el ticket si tiene impresora configurada.

### Cambiar o quitar un producto del carrito
- En la lista del carrito (lado derecho) suele haber opción para cambiar cantidad o quitar el ítem. Use esa opción antes de procesar la venta.

### Cerrar caja al final del día
- Desde el Punto de Venta o según le indique el menú, busque la opción de **Cerrar caja**. El sistema hará un arqueo y registrará el cierre. Es importante hacerlo cada día.

---

## 5. Inventario (productos)

### Ver y buscar productos
1. Menú → **Inventario** (o **Productos**, según la versión).
2. Use el buscador para filtrar por nombre o código.

### Agregar un producto nuevo
1. En Inventario, pulse el botón **+** o **Agregar producto**.
2. Complete:
   - **Nombre**
   - **Código** (opcional, útil para código de barras)
   - **Precio de venta**
   - **Precio de costo** (opcional, para reportes)
   - **Stock inicial** (cantidad)
   - **Unidad o Peso:** si se vende por unidad (cajas, botellas) o por peso (kg).
3. Guarde.

### Editar un producto
- En la lista, busque el producto y use **Editar** (o doble clic). Cambie lo necesario y guarde.

### Dar de baja un producto
- No borre productos con ventas históricas. Si debe dejar de venderlo, puede desactivarlo o marcar como “no disponible” si el programa lo permite, o pregunte a su técnico la forma recomendada.

---

## 6. Clientes y proveedores

### Clientes
- Menú → **Clientes**. Ahí puede agregar, editar y buscar clientes (nombre, documento, teléfono). Los datos sirven para facturas y reportes.

### Proveedores
- Menú → **Proveedores**. Igual que clientes: agregar, editar y usar en compras o cuentas por pagar si el módulo está activo.

---

## 7. Reportes y cuentas por cobrar

### Reportes
- Menú → **Reportes** (o **Reportes contables**).
- Elija tipo: ventas, inventario, contables, etc.
- Seleccione fechas (día, semana, mes o rango) y genere el reporte. Si hay opción **Exportar PDF**, úsela para guardar o imprimir.

### Cuentas por cobrar / por pagar
- Menú → **Cuentas por Cobrar**. Ahí verá resumen de lo que le deben y lo que usted debe, según lo que el programa tenga configurado.

---

## 8. Recogidas de efectivo

- Cuando saque dinero de caja (para pagar algo, llevar a banco, etc.), regístrelo:
  1. Menú → **Recogidas de Efectivo**.
  2. Registre el monto y el motivo (ej. “Pago proveedor”, “Depósito banco”).
  3. Así la caja y los reportes siguen cuadrando.

---

## 9. Datos de empresa y facturación

- Menú → **Datos de Empresa**.
- Ahí debe estar: nombre de la empresa, NIT, dirección, teléfono, ciudad. Esto sale en tickets y facturas.
- Si usa **facturación electrónica**, el técnico le habrá configurado ese módulo; no cambie datos fiscales sin avisar.

---

## 10. Usuarios y permisos (administrador)

- **Usuarios:** Menú → **Usuarios**. Ahí se crean usuarios nuevos (nombre, usuario, contraseña, rol).
- **Permisos:** Menú → **Permisos**. Se define qué puede hacer cada rol (vender, ver inventario, ver reportes, configurar, etc.). No quite todos los permisos al administrador.

Solo el administrador debe crear usuarios y tocar permisos. Si no es administrador y no ve estas opciones, es normal.

---

## 11. Problemas frecuentes y qué hacer

| Problema | Qué hacer |
|----------|-----------|
| **El programa no abre** | Ejecutar como administrador (clic derecho en el .exe → “Ejecutar como administrador”). Revisar que el antivirus no lo bloquee. |
| **“Debes abrir la caja”** | En Punto de Venta, abra caja con el monto inicial que indique el sistema. |
| **No encuentro un producto** | En Punto de Venta revise que esté buscando por nombre o código correcto. En Inventario verifique que el producto exista y no esté desactivado. |
| **No imprime el ticket** | Compruebe que la impresora esté encendida y conectada. En **Configuración** (o Configuración de impresora) verifique que esté seleccionada la impresora correcta. |
| **Error de base de datos** | No borre archivos de la carpeta del programa. Ejecute como administrador. Si sigue el error, anote el mensaje exacto y contacte al técnico. |
| **Olvidé la contraseña** | Solo el administrador o el técnico pueden restablecerla; contacte a uno de ellos. |

---

## 12. Respaldo (recomendado)

- La base de datos suele estar en una carpeta como:  
  `C:\Users\[SuUsuario]\AppData\Roaming\smart_seller\`  
  o dentro de la carpeta del programa (su técnico puede confirmar).
- **Recomendación:** copiar esa carpeta o el archivo de base de datos (por ejemplo `smart_seller.db`) a un USB o a la nube una vez a la semana. Así, si pasa algo, el técnico puede recuperar los datos.

---

## 13. Cuándo llamar al técnico

- Cambio de computadora o reinstalación del programa.
- Configuración de facturación electrónica o de impresora térmica.
- Errores que no desaparecen después de reiniciar el programa o el equipo.
- Crear o cambiar usuarios y permisos si no es administrador.
- Cualquier mensaje de error que no entienda: anote el texto completo o tome una captura de pantalla y envíela al técnico.

---

## Resumen rápido

1. **Abrir programa** → ejecutar **smart_seller.exe** (como administrador si es necesario).
2. **Entrar** → usuario y contraseña.
3. **Vender** → Punto de Venta → abrir caja si pide → buscar productos → agregar → Procesar Venta (F2) → elegir pago.
4. **Al cierre del día** → cerrar caja desde el POS.
5. **Productos nuevos** → Inventario → Agregar producto.
6. **Ver ventas o números** → Reportes.
7. **Sacar efectivo de caja** → Recogidas de Efectivo.
8. **Dudas o errores** → anotar mensaje o captura y contactar al técnico.

---

*Smart Seller POS – Manual básico para el cliente. Actualice la fecha según la versión que entregue.*
