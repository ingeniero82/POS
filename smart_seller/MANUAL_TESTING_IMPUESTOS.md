# Manual de Testing - Nuevas Funcionalidades de Impuestos

## Índice
1. [Configuración de IVA en Productos](#1-configuración-de-iva-en-productos)
2. [Configuración de IpoConsumo](#2-configuración-de-ipoconsumo)
3. [Configuración de Bolsas Plásticas](#3-configuración-de-bolsas-plásticas)
4. [Gestión de IVA por Categorías](#4-gestión-de-iva-por-categorías)
5. [Venta con Desglose de IVA](#5-venta-con-desglose-de-iva)
6. [Venta con IpoConsumo](#6-venta-con-ipoconsumo)
7. [Venta con Bolsas Plásticas](#7-venta-con-bolsas-plásticas)
8. [Recogidas de Efectivo](#8-recogidas-de-efectivo)
9. [Reportes con Desglose Completo](#9-reportes-con-desglose-completo)
10. [Casos de Error y Validaciones](#10-casos-de-error-y-validaciones)

---

## 1. Configuración de IVA en Productos

### Objetivo
Verificar que se pueden configurar correctamente los tipos y tasas de IVA en los productos.

### Pasos de Prueba

#### 1.1 Crear Producto con IVA Gravado al 19%
1. Ir a **Inventario** → **Crear Producto**
2. Llenar información básica:
   - Nombre: `Producto Test IVA 19`
   - Código: `TEST-IVA19-001`
   - Precio: `10000`
   - Costo: `7000`
   - Stock: `100`
3. Ir a la pestaña **"Facturación Electrónica"**
4. En **"Clasificación Fiscal"**: Seleccionar `Gravado`
5. En **"Tasa de IVA"**: Seleccionar `19%`
6. Guardar producto

**Resultado Esperado:**
- ✅ Producto creado exitosamente
- ✅ Los campos de IVA se guardan correctamente

#### 1.2 Crear Producto con IVA Gravado al 5%
1. Crear nuevo producto: `Producto Test IVA 5`
2. Código: `TEST-IVA5-001`
3. En "Facturación Electrónica":
   - Clasificación Fiscal: `Gravado`
   - Tasa de IVA: `5%`
4. Guardar

**Resultado Esperado:**
- ✅ Producto creado con IVA 5%

#### 1.3 Crear Producto Exento de IVA
1. Crear nuevo producto: `Producto Test Exento`
2. Código: `TEST-EXENTO-001`
3. En "Facturación Electrónica":
   - Clasificación Fiscal: `Exento`
   - Verificar que "Tasa de IVA" automáticamente se pone en `0%`
4. Guardar

**Resultado Esperado:**
- ✅ Al seleccionar "Exento", la tasa se cambia automáticamente a 0%
- ✅ Producto guardado correctamente

#### 1.4 Crear Producto Excluido de IVA
1. Crear nuevo producto: `Producto Test Excluido`
2. Código: `TEST-EXCLUIDO-001`
3. En "Facturación Electrónica":
   - Clasificación Fiscal: `Excluido`
   - Verificar que "Tasa de IVA" automáticamente se pone en `0%`
4. Guardar

**Resultado Esperado:**
- ✅ Al seleccionar "Excluido", la tasa se cambia automáticamente a 0%

#### 1.5 Editar Producto Existente y Cambiar IVA
1. Buscar un producto existente
2. Hacer clic en **Editar**
3. Ir a "Facturación Electrónica"
4. Cambiar la clasificación fiscal y tasa
5. Guardar cambios

**Resultado Esperado:**
- ✅ Los cambios se guardan correctamente
- ✅ El producto actualizado mantiene los nuevos valores de IVA

---

## 2. Configuración de IpoConsumo

### Objetivo
Verificar que se puede configurar el Impuesto al Consumo en productos.

### Pasos de Prueba

#### 2.1 Crear Producto con IpoConsumo - Licor
1. Crear nuevo producto: `Licor Test`
2. Código: `TEST-LICOR-001`
3. Precio: `50000`
4. En la pestaña **"Facturación Electrónica"**, buscar la sección **"Impuesto al Consumo (IpoConsumo)"**
5. Activar el checkbox **"Producto con Impuesto al Consumo"**
6. Seleccionar Tipo: `Licor`
7. Ingresar Tasa: `8` (esto significa 8%)
8. Guardar producto

**Resultado Esperado:**
- ✅ El checkbox activa los campos de tipo y tasa
- ✅ Los campos se guardan correctamente

#### 2.2 Crear Producto con IpoConsumo - Cigarrillos
1. Crear producto: `Cigarrillos Test`
2. Código: `TEST-CIGARRILLOS-001`
3. Activar IpoConsumo
4. Tipo: `Cigarrillos`
5. Tasa: `10`
6. Guardar

**Resultado Esperado:**
- ✅ Producto guardado con IpoConsumo de cigarrillos

#### 2.3 Desactivar IpoConsumo
1. Editar un producto con IpoConsumo activo
2. Desactivar el checkbox "Producto con Impuesto al Consumo"
3. Verificar que los campos de tipo y tasa se ocultan/limpian
4. Guardar

**Resultado Esperado:**
- ✅ Los campos se limpian cuando se desactiva
- ✅ El producto se guarda sin IpoConsumo

---

## 3. Configuración de Bolsas Plásticas

### Objetivo
Verificar que se puede configurar el impuesto de bolsas plásticas.

### Pasos de Prueba

#### 3.1 Crear Producto - Bolsa Plástica
1. Crear nuevo producto: `Bolsa Plástica Grande`
2. Código: `TEST-BOLSA-001`
3. Precio: `100` (precio de la bolsa)
4. En "Facturación Electrónica", buscar **"Control de Bolsas Plásticas"**
5. Activar checkbox **"Es una bolsa plástica"**
6. Ingresar en **"Impuesto por Bolsa"**: `50` (pesos colombianos)
7. Guardar producto

**Resultado Esperado:**
- ✅ El checkbox activa el campo de impuesto
- ✅ El impuesto se guarda correctamente

#### 3.2 Desactivar Bolsa Plástica
1. Editar un producto marcado como bolsa
2. Desactivar el checkbox
3. Verificar que el campo de impuesto se limpia
4. Guardar

**Resultado Esperado:**
- ✅ Los campos se limpian al desactivar

---

## 5. Venta con Desglose de IVA

### Objetivo
Verificar que las ventas calculan correctamente el IVA y generan el desglose.

### Pasos de Prueba

#### 5.1 Venta con Producto Gravado al 19%
1. Ir a **Punto de Venta**
2. Agregar al carrito el producto "Producto Test IVA 19" (precio $10,000)
3. Cantidad: `1`
4. Verificar en el resumen del carrito que se muestra:
   - Subtotal: $10,000
   - IVA (19%): $1,900
   - Total: $11,900
5. Procesar el pago
6. Realizar la venta

**Resultado Esperado:**
- ✅ El IVA se calcula correctamente (19% de $10,000 = $1,900)
- ✅ El total es correcto ($11,900)

#### 5.2 Venta con Producto Gravado al 5%
1. Agregar "Producto Test IVA 5" (precio $10,000)
2. Cantidad: `1`
3. Verificar:
   - Subtotal: $10,000
   - IVA (5%): $500
   - Total: $10,500
4. Procesar pago

**Resultado Esperado:**
- ✅ IVA calculado al 5% correctamente

#### 5.3 Venta con Producto Exento
1. Agregar "Producto Test Exento" (precio $10,000)
2. Cantidad: `1`
3. Verificar:
   - Subtotal: $10,000
   - IVA: $0
   - Total: $10,000
4. Procesar pago

**Resultado Esperado:**
- ✅ No se aplica IVA a productos exentos

#### 5.4 Venta Mixta (Gravado + Exento)
1. Agregar al carrito:
   - "Producto Test IVA 19" x1 ($10,000)
   - "Producto Test Exento" x1 ($10,000)
2. Verificar totales:
   - Subtotal: $20,000
   - IVA: $1,900 (solo del producto gravado)
   - Total: $21,900
3. Procesar pago

**Resultado Esperado:**
- ✅ Se calcula IVA solo para el producto gravado
- ✅ El total es correcto

---

## 6. Venta con IpoConsumo

### Objetivo
Verificar que el IpoConsumo se calcula y aplica correctamente.

### Pasos de Prueba

#### 6.1 Venta con Licor (IpoConsumo 8%)
1. Agregar al carrito: "Licor Test" (precio $50,000)
2. Cantidad: `1`
3. Verificar cálculo:
   - Subtotal: $50,000
   - IVA (si aplica): [calcular según tipo de IVA del producto]
   - IpoConsumo (8%): $4,000 (50,000 * 0.08)
   - Total: [Subtotal + IVA + IpoConsumo]
4. Procesar pago

**Resultado Esperado:**
- ✅ IpoConsumo calculado: $50,000 * 8% = $4,000
- ✅ El total incluye IpoConsumo

#### 6.2 Venta con Cigarrillos (IpoConsumo 10%)
1. Agregar "Cigarrillos Test" (precio $10,000)
2. Cantidad: `2`
3. Verificar:
   - Subtotal: $20,000
   - IpoConsumo (10%): $2,000 (20,000 * 0.10)
   - Total: [correspondiente]
4. Procesar pago

**Resultado Esperado:**
- ✅ IpoConsumo calculado correctamente sobre el subtotal

---

## 7. Venta con Bolsas Plásticas

### Objetivo
Verificar que el impuesto de bolsas se calcula por cantidad.

### Pasos de Prueba

#### 7.1 Venta de Bolsas Plásticas
1. Agregar al carrito: "Bolsa Plástica Grande" (precio $100, impuesto $50)
2. Cantidad: `10` bolsas
3. Verificar cálculo:
   - Precio producto: $100 x 10 = $1,000
   - Impuesto bolsas: $50 x 10 = $500
   - Total: $1,500
4. Procesar pago

**Resultado Esperado:**
- ✅ Impuesto calculado: $50 * 10 = $500
- ✅ El total incluye precio de bolsas + impuesto

#### 7.2 Venta Mixta con Bolsas
1. Agregar:
   - Producto normal x1 ($10,000)
   - Bolsa Plástica x5 (precio $100, impuesto $50)
2. Verificar:
   - Subtotal productos: $10,000
   - Precio bolsas: $500 (100 * 5)
   - Impuesto bolsas: $250 (50 * 5)
   - Total: $10,750
3. Procesar pago

**Resultado Esperado:**
- ✅ Se calculan correctamente productos y bolsas por separado
- ✅ El impuesto de bolsas es por cantidad

---

## 8. Recogidas de Efectivo

### Objetivo
Verificar que se pueden registrar y gestionar recogidas de efectivo.

### Pasos de Prueba

#### 8.1 Acceder a Recogidas de Efectivo
1. En el dashboard, buscar el menú **"Recogidas de Efectivo"**
2. Verificar que aparece en el menú lateral (si tienes permisos)
3. Hacer clic para abrir la pantalla

**Resultado Esperado:**
- ✅ La opción aparece en el menú
- ✅ Se abre la pantalla correctamente

#### 8.2 Registrar Nueva Recogida - Retiro Parcial
1. Hacer clic en el botón **"Nueva Recogida"** (FAB verde)
2. Llenar el formulario:
   - Monto: `50000`
   - Razón: `Retiro parcial`
   - Notas: `Retiro para cambio`
3. Hacer clic en **"Registrar Recogida"**

**Resultado Esperado:**
- ✅ Se muestra mensaje de éxito
- ✅ La recogida aparece en la lista
- ✅ Se muestra el monto, razón, usuario y fecha

#### 8.3 Registrar Recogida - Pago a Proveedor
1. Nueva recogida:
   - Monto: `100000`
   - Razón: `Pago a proveedor`
   - Notas: `Pago factura #12345`
2. Registrar

**Resultado Esperado:**
- ✅ Recogida registrada correctamente

#### 8.4 Verificar Resumen
1. En la parte superior de la pantalla, verificar el resumen:
   - Total Recogidas: Suma de todas las recogidas
   - Cantidad: Número de recogidas registradas

**Resultado Esperado:**
- ✅ Los totales se calculan correctamente
- ✅ La cantidad es correcta

#### 8.5 Filtrar por Fecha
1. Hacer clic en el icono de filtro (funnel)
2. Seleccionar un rango de fechas
3. Verificar que solo se muestran las recogidas del rango

**Resultado Esperado:**
- ✅ El filtro funciona correctamente

#### 8.6 Eliminar Recogida
1. En la lista, hacer clic en el icono de eliminar (🗑️) de una recogida
2. Confirmar la eliminación en el diálogo
3. Verificar que se elimina de la lista

**Resultado Esperado:**
- ✅ Se muestra diálogo de confirmación
- ✅ La recogida se elimina correctamente

#### 8.7 Validar Sesión de Caja
1. Intentar registrar una recogida SIN tener sesión de caja abierta
2. Verificar que muestra un mensaje de error indicando que debe abrir una sesión primero

**Resultado Esperado:**
- ✅ Se muestra mensaje de error claro
- ✅ No permite registrar sin sesión abierta

---

## 9. Reportes con Desglose Completo

### Objetivo
Verificar que los reportes muestran todos los desgloses de impuestos.

### Pasos de Prueba

#### 9.1 Generar Reporte de Ventas del Día
1. Ir a **Reportes**
2. Seleccionar período: **"Hoy"** o **"Día específico"**
3. Generar reporte de ventas
4. Verificar que el reporte incluye:

**Sección de Desglose de Ventas:**
- Ventas Exentas: [total]
- Ventas Excluidas: [total]
- Ventas Gravadas: [total]

**Sección de IVA:**
- IVA a tasa 0%: [total]
- IVA a tasa 5%: [total]
- IVA a tasa 19%: [total]
- Total IVA: [suma de todos]

**Sección de Impuestos Adicionales:**
- Total IpoConsumo: [total]
- Impuesto Bolsas: [total]
- Cantidad Bolsas: [número]

**Resultado Esperado:**
- ✅ Todos los desgloses están presentes
- ✅ Los valores son correctos
- ✅ Las sumas cuadran

---

## 10. Casos de Error y Validaciones

### Objetivo
Verificar que el sistema valida correctamente los datos y maneja errores.

### Pasos de Prueba

#### 10.1 Validación - Monto Negativo en Recogida
1. Intentar registrar recogida con monto negativo: `-10000`
2. Verificar comportamiento

**Resultado Esperado:**
- ✅ Muestra error o no permite valores negativos

#### 10.2 Validación - Monto Cero en Recogida
1. Intentar registrar recogida con monto: `0`
2. Verificar comportamiento

**Resultado Esperado:**
- ✅ Muestra error indicando que el monto debe ser mayor a 0

#### 10.3 Validación - IpoConsumo Sin Tipo
1. Activar checkbox de IpoConsumo en un producto
2. NO seleccionar tipo
3. Intentar guardar

**Resultado Esperado:**
- ✅ Muestra error indicando que debe seleccionar tipo

#### 10.4 Validación - Bolsa Sin Impuesto
1. Marcar producto como bolsa plástica
2. NO ingresar impuesto por bolsa
3. Intentar guardar

**Resultado Esperado:**
- ✅ Muestra error indicando que debe ingresar impuesto

---

## Checklist Final de Testing

### Configuración
- [ ] Productos con IVA 19% se configuran correctamente
- [ ] Productos con IVA 5% se configuran correctamente
- [ ] Productos exentos se configuran correctamente
- [ ] Productos excluidos se configuran correctamente
- [ ] IpoConsumo se configura para diferentes tipos
- [ ] Bolsas plásticas se configuran con impuesto

### Ventas
- [ ] IVA se calcula correctamente en ventas
- [ ] IpoConsumo se calcula correctamente
- [ ] Impuesto de bolsas se calcula por cantidad
- [ ] Desglose de ventas (exenta/excluida/gravada) es correcto
- [ ] Totales de venta son correctos

### Recogidas de Efectivo
- [ ] Se pueden registrar recogidas
- [ ] Se pueden filtrar por fecha
- [ ] Se pueden eliminar recogidas
- [ ] El resumen es correcto
- [ ] Se integra con contabilidad

### Reportes
- [ ] Reportes muestran desglose de IVA por tasas
- [ ] Reportes muestran IpoConsumo
- [ ] Reportes muestran impuesto de bolsas
- [ ] Reportes muestran ventas exentas/excluidas/gravadas
- [ ] Totales en reportes cuadran

### Validaciones
- [ ] Se validan montos negativos/cero
- [ ] Se validan campos obligatorios
- [ ] Se valida sesión de caja abierta
- [ ] Se validan inconsistencias de IVA

---

## Notas para el Tester

1. **Datos de Prueba**: Crea productos de prueba claramente identificables (ej: "TEST-IVA19-001") para facilitar la verificación.

2. **Sesión de Caja**: Para probar recogidas, necesitas tener una sesión de caja abierta.

3. **Permisos**: Asegúrate de tener los permisos necesarios para acceder a todas las funcionalidades.

4. **Revertir Cambios**: Después de las pruebas, puedes eliminar los productos y ventas de prueba.

---

**Versión del manual**: 1.0
**Fecha de creación**: [Fecha actual]





















