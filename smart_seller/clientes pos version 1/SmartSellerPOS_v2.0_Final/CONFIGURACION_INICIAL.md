# ⚙️ Configuración Inicial - Smart Seller POS

## 🎯 **CONFIGURACIÓN RECOMENDADA PARA EL CLIENTE**

### **1. PRIMER INICIO DE SESIÓN**
```
Usuario: admin
Contraseña: 123456
```

### **2. CONFIGURACIÓN DE EMPRESA (OBLIGATORIA)**

#### **Datos Básicos:**
- **Nombre de la Empresa:** [Nombre del negocio del cliente]
- **Dirección:** [Dirección completa]
- **Teléfono:** [Teléfono principal]
- **Email:** [Email de contacto]
- **Sitio Web:** [Opcional]

#### **Para Facturación Electrónica DIAN:**
- **Tipo de Documento:** 31 (NIT)
- **Número de NIT:** [NIT de la empresa]
- **Dígito de Verificación:** [DV del NIT]
- **Ciudad:** [Ciudad donde opera]
- **Departamento:** [Departamento]
- **País:** CO (Colombia)
- **Régimen Fiscal:** [Común, Simplificado, etc.]
- **Responsabilidades Fiscales:** [O-13, I-23, etc.]

#### **Textos de Factura:**
- **Texto de Cabecera:** "Gracias por su compra"
- **Texto de Pie:** "Vuelva pronto"

### **3. CREAR USUARIOS DEL SISTEMA**

#### **Usuario Administrador (Principal):**
- **Nombre:** [Nombre del dueño/gerente]
- **Usuario:** admin_principal
- **Contraseña:** [Contraseña segura]
- **Rol:** Administrador
- **Permisos:** Todos

#### **Usuarios Vendedores:**
- **Nombre:** [Nombre del vendedor]
- **Usuario:** vendedor1
- **Contraseña:** [Contraseña segura]
- **Rol:** Vendedor
- **Permisos:** POS, Clientes, Reportes básicos

### **4. CONFIGURAR PRODUCTOS INICIALES**

#### **Productos de Ejemplo (Eliminar después):**
- **Manzanas** - $3,000/kg - Peso
- **Coca Cola** - $2,500 - Unidad
- **Pan** - $1,200 - Unidad
- **Carne** - $15,000/kg - Peso

#### **Categorías Recomendadas:**
- **Bebidas**
- **Frutas y Verduras**
- **Carnes**
- **Panadería**
- **Lácteos**
- **Aseo**

### **5. CONFIGURAR MÉTODOS DE PAGO**

#### **Métodos Disponibles:**
- **Efectivo** (Principal)
- **Tarjeta Débito**
- **Tarjeta Crédito**
- **Transferencia**
- **Cheque** (Opcional)

### **6. CONFIGURAR IMPRESIÓN**

#### **Impresora de Tickets:**
- **Modelo:** [Modelo de impresora térmica]
- **Puerto:** USB o Red
- **Configuración:** 80mm de ancho

#### **Impresora de Facturas:**
- **Modelo:** [Impresora láser/inyección]
- **Formato:** A4
- **Configuración:** Facturación electrónica

### **7. CONFIGURAR BALANZA (SI APLICA)**

#### **Productos por Peso:**
- **Frutas:** Manzanas, Peras, Bananos
- **Verduras:** Tomates, Cebollas, Papas
- **Carnes:** Res, Pollo, Cerdo
- **Granos:** Arroz, Frijoles, Lentejas

### **8. CONFIGURAR REPORTES**

#### **Reportes Diarios:**
- **Horario:** Al final del día
- **Tipo:** Ventas, Inventario, Caja
- **Formato:** PDF

#### **Reportes Semanales:**
- **Día:** Domingo
- **Tipo:** Resumen semanal
- **Envío:** Email (opcional)

### **9. CONFIGURAR RESPALDOS**

#### **Respaldo Automático:**
- **Frecuencia:** Diaria
- **Hora:** 23:00
- **Ubicación:** C:\SmartSellerPOS\Backups\
- **Retención:** 30 días

### **10. CONFIGURAR SEGURIDAD**

#### **Contraseñas:**
- **Mínimo 8 caracteres**
- **Incluir números y letras**
- **Cambiar cada 3 meses**

#### **Permisos:**
- **Vendedores:** Solo POS y clientes
- **Cajeros:** POS y caja
- **Administradores:** Acceso completo

---

## 📋 **CHECKLIST DE CONFIGURACIÓN**

### **Antes de Entregar al Cliente:**
- [ ] Configurar datos de empresa
- [ ] Crear usuarios principales
- [ ] Configurar productos básicos
- [ ] Probar venta completa
- [ ] Probar reportes
- [ ] Configurar impresión
- [ ] Crear respaldo inicial
- [ ] Documentar credenciales
- [ ] Entregar manual de usuario

### **Configuración del Cliente:**
- [ ] Cambiar contraseña admin
- [ ] Agregar productos reales
- [ ] Configurar impresoras
- [ ] Crear usuarios vendedores
- [ ] Probar todas las funciones
- [ ] Configurar respaldos
- [ ] Personalizar textos de factura

---

## 🚨 **NOTAS IMPORTANTES**

### **Base de Datos:**
- **Ubicación:** C:\Users\[Usuario]\Documents\smart_seller.db
- **Respaldo:** C:\SmartSellerPOS\Backups\
- **Tamaño inicial:** ~1MB
- **Crecimiento:** ~1MB por mes

### **Rendimiento:**
- **RAM recomendada:** 8GB
- **Espacio disco:** 2GB mínimo
- **Procesador:** Intel i3 o superior

### **Soporte:**
- **Horario:** Lunes a Viernes, 8:00 AM - 6:00 PM
- **Tiempo respuesta:** 24 horas
- **Canal preferido:** Email o WhatsApp

---

**Smart Seller POS v2.0** - Configuración Profesional  
*Sistema listo para producción*
