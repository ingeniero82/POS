# 🏗️ ARQUITECTURA E INGENIERÍA - NUEVO PROYECTO
## Migración de Flutter Desktop a React + Node.js + PostgreSQL

---

## 📊 ANÁLISIS DE LA ARQUITECTURA ACTUAL

### **Stack Actual (Flutter Desktop):**
```
┌─────────────────────────────────────┐
│   CAPA DE PRESENTACIÓN              │
│   - Flutter Widgets (Dart)         │
│   - GetX (Estado y Navegación)      │
│   - Material Design 3               │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   CAPA DE LÓGICA DE NEGOCIO         │
│   - Services (Auth, Permissions)    │
│   - Controllers (GetX)              │
│   - Middleware (Auth, Guest)        │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   CAPA DE DATOS                      │
│   - SQLite (Local)                   │
│   - SQLiteDatabaseService            │
│   - Modelos (Product, Sale, User)    │
└──────────────────────────────────────┘
```

### **Problemas Identificados:**
1. ❌ **Flutter Desktop inmaduro** - Problemas de distribución
2. ❌ **SQLite limitado** - Solo 1 escritor, no escala
3. ❌ **Monolítico** - Todo en una aplicación
4. ❌ **Sin separación clara** - Frontend y backend mezclados
5. ❌ **Difícil de escalar** - No puede sincronizar multi-tienda

---

## 🎯 ARQUITECTURA PROPUESTA (React + Node.js + PostgreSQL)

### **Arquitectura en Capas (3-Tier):**

```
┌─────────────────────────────────────────────────────────┐
│                    CAPA DE PRESENTACIÓN                  │
│                    (Frontend - React)                     │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Login      │  │  Dashboard   │  │     POS      │  │
│  │   Screen     │  │   Screen     │  │   Screen     │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Products    │  │  Customers   │  │   Reports   │  │
│  │   Screen     │  │   Screen     │  │   Screen    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                           │
│  - React + TypeScript                                  │
│  - React Router (Navegación)                           │
│  - React Query (Estado y Cache)                         │
│  - Service Workers (PWA - Offline)                     │
│  - IndexedDB (Cache Local)                              │
└───────────────────────┬─────────────────────────────────┘
                        │ HTTP/REST (JSON)
┌───────────────────────▼─────────────────────────────────┐
│                  CAPA DE APLICACIÓN                     │
│                  (Backend - Node.js)                     │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Auth       │  │   Products   │  │    Sales    │  │
│  │  Controller  │  │  Controller  │  │  Controller │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Customers   │  │   Reports    │  │  Permissions │  │
│  │  Controller  │  │  Controller  │  │   Service    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                           │
│  - Express.js (API REST)                                │
│  - TypeScript                                            │
│  - JWT (Autenticación)                                   │
│  - Middleware (Auth, Validation, Error Handling)        │
│  - Services (Lógica de Negocio)                         │
└───────────────────────┬─────────────────────────────────┘
                        │ SQL (Prisma ORM)
┌───────────────────────▼─────────────────────────────────┐
│                    CAPA DE DATOS                        │
│                  (PostgreSQL)                            │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │    Users     │  │   Products   │  │    Sales     │  │
│  │    Table    │  │    Table      │  │    Table    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Customers   │  │  Inventory   │  │   Groups    │  │
│  │    Table     │  │  Movements   │  │    Table    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                           │
│  - PostgreSQL (Base de Datos Relacional)               │
│  - Prisma ORM (Gestión de Datos)                       │
│  - Migraciones Automáticas                             │
│  - Índices Optimizados                                 │
└─────────────────────────────────────────────────────────┘
```

---

## 📐 MODELO DE DATOS (PostgreSQL)

### **Entidades Principales:**

#### **1. Users (Usuarios)**
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(100) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL, -- bcrypt
  full_name VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL, -- admin, manager, supervisor, cashier, maintenance
  user_code VARCHAR(50) UNIQUE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_role ON users(role);
```

#### **2. Groups (Grupos/Categorías)**
```sql
CREATE TABLE groups (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL,
  description TEXT,
  color VARCHAR(7) NOT NULL, -- Hex color
  icon VARCHAR(50) NOT NULL,
  default_vat_rate DECIMAL(5,4) DEFAULT 0.19,
  default_vat_type VARCHAR(20) DEFAULT 'GRAVADO',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

#### **3. Products (Productos)**
```sql
CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  code VARCHAR(100) UNIQUE NOT NULL,
  short_code VARCHAR(50) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  cost DECIMAL(10,2) NOT NULL,
  stock INTEGER DEFAULT 0,
  min_stock INTEGER DEFAULT 0,
  category VARCHAR(255) NOT NULL, -- Nombre del grupo
  unit VARCHAR(50) NOT NULL,
  image_url TEXT,
  
  -- Productos por peso
  is_weighted BOOLEAN DEFAULT false,
  price_per_kg DECIMAL(10,2),
  weight DECIMAL(10,3),
  min_weight DECIMAL(10,3),
  max_weight DECIMAL(10,3),
  
  -- Impuestos
  vat_type VARCHAR(20) DEFAULT 'GRAVADO', -- EXENTO, EXCLUIDO, GRAVADO
  vat_rate DECIMAL(5,4) DEFAULT 0.19,
  
  -- IpoConsumo
  has_ipo_consumo BOOLEAN DEFAULT false,
  ipo_consumo_rate DECIMAL(5,4),
  ipo_consumo_type VARCHAR(50), -- LICOR, CIGARRILLOS, BOLSAS, OTRO
  
  -- Bolsas plásticas
  is_plastic_bag BOOLEAN DEFAULT false,
  plastic_bag_tax DECIMAL(10,2),
  
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_products_code ON products(code);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_active ON products(is_active);
```

#### **4. Sales (Ventas)**
```sql
CREATE TABLE sales (
  id SERIAL PRIMARY KEY,
  sale_date TIMESTAMP NOT NULL DEFAULT NOW(),
  user_id INTEGER NOT NULL REFERENCES users(id),
  customer_id INTEGER REFERENCES customers(id),
  
  -- Totales
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.0,
  total DECIMAL(10,2) NOT NULL,
  discount DECIMAL(10,2) DEFAULT 0.0,
  discount_percentage DECIMAL(5,2) DEFAULT 0.0,
  
  -- Desglose de IVA
  exempt_amount DECIMAL(10,2) DEFAULT 0.0,
  excluded_amount DECIMAL(10,2) DEFAULT 0.0,
  taxed_amount DECIMAL(10,2) DEFAULT 0.0,
  vat_at_0 DECIMAL(10,2) DEFAULT 0.0,
  vat_at_5 DECIMAL(10,2) DEFAULT 0.0,
  vat_at_19 DECIMAL(10,2) DEFAULT 0.0,
  total_vat DECIMAL(10,2) DEFAULT 0.0,
  
  -- IpoConsumo y bolsas
  ipo_consumo_amount DECIMAL(10,2) DEFAULT 0.0,
  plastic_bag_tax_amount DECIMAL(10,2) DEFAULT 0.0,
  plastic_bag_count INTEGER DEFAULT 0,
  
  -- Devoluciones
  is_return BOOLEAN DEFAULT false,
  original_sale_id INTEGER REFERENCES sales(id),
  returned_amount DECIMAL(10,2) DEFAULT 0.0,
  
  -- Pago
  payment_method VARCHAR(50), -- efectivo, tarjeta, transferencia, cheque
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_sales_date ON sales(sale_date);
CREATE INDEX idx_sales_user ON sales(user_id);
CREATE INDEX idx_sales_customer ON sales(customer_id);
```

#### **5. Sale Items (Items de Venta)**
```sql
CREATE TABLE sale_items (
  id SERIAL PRIMARY KEY,
  sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id INTEGER REFERENCES products(id),
  product_name VARCHAR(255) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  quantity INTEGER NOT NULL,
  unit VARCHAR(50) NOT NULL,
  
  -- Descuentos
  discount DECIMAL(10,2),
  discount_percentage DECIMAL(5,2),
  
  -- Impuestos del item
  vat_type VARCHAR(20) DEFAULT 'GRAVADO',
  vat_rate DECIMAL(5,4) DEFAULT 0.19,
  item_vat DECIMAL(10,2) DEFAULT 0.0,
  
  -- IpoConsumo
  has_ipo_consumo BOOLEAN DEFAULT false,
  ipo_consumo_rate DECIMAL(5,4),
  ipo_consumo_type VARCHAR(50),
  item_ipo_consumo DECIMAL(10,2) DEFAULT 0.0,
  
  -- Bolsas
  is_plastic_bag BOOLEAN DEFAULT false,
  plastic_bag_tax DECIMAL(10,2),
  bag_quantity INTEGER,
  
  -- Subtotal
  item_subtotal DECIMAL(10,2) NOT NULL,
  
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_sale_items_sale ON sale_items(sale_id);
CREATE INDEX idx_sale_items_product ON sale_items(product_id);
```

#### **6. Customers (Clientes)**
```sql
CREATE TABLE customers (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255),
  phone VARCHAR(50),
  address TEXT,
  document_number VARCHAR(50),
  document_type VARCHAR(50), -- CEDULA, NIT, etc.
  
  -- Sistema de puntos (opcional)
  points_rate DECIMAL(5,2) DEFAULT 1.0,
  accumulated_points INTEGER DEFAULT 0,
  last_purchase TIMESTAMP,
  total_purchases DECIMAL(10,2) DEFAULT 0.0,
  
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_customers_document ON customers(document_number);
CREATE INDEX idx_customers_name ON customers(name);
```

#### **7. Inventory Movements (Movimientos de Inventario)**
```sql
CREATE TABLE inventory_movements (
  id SERIAL PRIMARY KEY,
  product_id INTEGER NOT NULL REFERENCES products(id),
  type VARCHAR(50) NOT NULL, -- ENTRADA, SALIDA, AJUSTE
  quantity INTEGER NOT NULL,
  reason VARCHAR(255) NOT NULL,
  description TEXT,
  movement_date TIMESTAMP NOT NULL DEFAULT NOW(),
  user_id INTEGER NOT NULL REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_inventory_movements_product ON inventory_movements(product_id);
CREATE INDEX idx_inventory_movements_date ON inventory_movements(movement_date);
```

#### **8. Company Config (Configuración de Empresa)**
```sql
CREATE TABLE company_config (
  id SERIAL PRIMARY KEY,
  company_name VARCHAR(255) NOT NULL,
  address TEXT NOT NULL,
  phone VARCHAR(50) NOT NULL,
  email VARCHAR(255),
  website VARCHAR(255),
  tax_id VARCHAR(50), -- NIT
  header_text TEXT NOT NULL,
  footer_text TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

#### **9. Permissions (Permisos - Tabla de Relación)**
```sql
CREATE TABLE role_permissions (
  id SERIAL PRIMARY KEY,
  role VARCHAR(50) NOT NULL,
  permission VARCHAR(100) NOT NULL,
  UNIQUE(role, permission)
);

-- Insertar permisos por defecto
INSERT INTO role_permissions (role, permission) VALUES
  ('admin', 'viewUsers'),
  ('admin', 'createUsers'),
  ('admin', 'editUsers'),
  -- ... todos los permisos de admin
  ('cashier', 'viewProducts'),
  ('cashier', 'accessPOS'),
  ('cashier', 'processSales'),
  -- ... permisos de cashier
  -- etc.
```

---

## 🔧 SERVICIOS Y LÓGICA DE NEGOCIO

### **Backend Services (Node.js):**

#### **1. AuthService**
```typescript
// src/services/auth.service.ts
- login(username, password): Promise<{ user, token }>
- logout(token): Promise<void>
- verifyToken(token): Promise<User>
- refreshToken(token): Promise<string>
```

#### **2. PermissionsService**
```typescript
// src/services/permissions.service.ts
- hasPermission(role, permission): boolean
- getRolePermissions(role): Permission[]
- canAccessSection(role, section): boolean
```

#### **3. TaxCalculationService**
```typescript
// src/services/tax-calculation.service.ts
- calculateItemTaxes(product, quantity, discount?): SaleItem
- calculateSaleBreakdown(items, discount?): Sale
- getVatBreakdown(sale): VatBreakdown
```

#### **4. InventoryService**
```typescript
// src/services/inventory.service.ts
- updateStock(productId, quantity, type, reason): InventoryMovement
- getLowStockProducts(): Product[]
- getInventoryMovements(filters): InventoryMovement[]
```

#### **5. ReportsService**
```typescript
// src/services/reports.service.ts
- generateSalesReport(dateFrom, dateTo): SalesReport
- generateInventoryReport(): InventoryReport
- generateTaxReport(dateFrom, dateTo): TaxReport
- exportToPDF(report): Buffer
- exportToExcel(report): Buffer
```

---

## 🎨 FRONTEND (React + TypeScript)

### **Estructura de Carpetas:**
```
frontend/
├── src/
│   ├── components/          # Componentes reutilizables
│   │   ├── common/
│   │   ├── forms/
│   │   └── layout/
│   ├── pages/              # Páginas/Pantallas
│   │   ├── Login/
│   │   ├── Dashboard/
│   │   ├── POS/
│   │   ├── Products/
│   │   ├── Customers/
│   │   └── Reports/
│   ├── services/           # Servicios API
│   │   ├── api.ts
│   │   ├── auth.service.ts
│   │   ├── products.service.ts
│   │   └── sales.service.ts
│   ├── hooks/              # Custom Hooks
│   │   ├── useAuth.ts
│   │   ├── usePermissions.ts
│   │   └── useProducts.ts
│   ├── store/              # Estado Global (Zustand/Redux)
│   │   ├── auth.store.ts
│   │   └── cart.store.ts
│   ├── types/              # TypeScript Types
│   │   ├── user.types.ts
│   │   ├── product.types.ts
│   │   └── sale.types.ts
│   ├── utils/              # Utilidades
│   │   ├── formatters.ts
│   │   └── validators.ts
│   └── App.tsx
├── public/
└── package.json
```

### **Tecnologías Frontend:**
- **React 18** + **TypeScript**
- **React Router** (Navegación)
- **React Query** (Estado y Cache)
- **Zustand** (Estado Global)
- **Material-UI** o **Ant Design** (Componentes)
- **React Hook Form** (Formularios)
- **Service Workers** (PWA - Offline)

---

## 🔐 SEGURIDAD Y AUTENTICACIÓN

### **JWT (JSON Web Tokens):**
```typescript
// Estructura del Token
{
  userId: number,
  username: string,
  role: string,
  permissions: string[],
  exp: number // Expiración
}

// Middleware de Autenticación
- Verificar token en cada request
- Refrescar token automáticamente
- Logout cuando token expira
```

### **Permisos:**
- **RBAC (Role-Based Access Control)**
- Permisos granulares por módulo
- Verificación en frontend y backend
- Middleware de autorización en rutas

---

## 📦 OFFLINE Y SINCRONIZACIÓN (PWA)

### **Service Workers:**
```typescript
// Cache de datos críticos
- Productos (IndexedDB)
- Clientes (IndexedDB)
- Ventas pendientes (IndexedDB)

// Sincronización
- Guardar ventas offline
- Sincronizar cuando hay internet
- Resolver conflictos
```

### **IndexedDB (Cache Local):**
```typescript
// Estructura
- products: Product[]
- customers: Customer[]
- pending_sales: Sale[]
- sync_queue: SyncItem[]
```

---

## 🚀 PLAN DE IMPLEMENTACIÓN

### **FASE 1: Setup y Backend (4-5 semanas)**
1. Setup proyecto Node.js + TypeScript
2. Setup PostgreSQL + Prisma
3. Crear modelos de datos
4. Implementar AuthService
5. Implementar API REST básica

### **FASE 2: Frontend Core (4-5 semanas)**
1. Setup React + TypeScript
2. Implementar Login
3. Implementar Dashboard
4. Implementar POS básico
5. Conectar con API

### **FASE 3: Funcionalidades Completas (4-5 semanas)**
1. Gestión de productos
2. Gestión de clientes
3. Reportes
4. Configuración
5. Permisos

### **FASE 4: PWA y Optimización (2-3 semanas)**
1. Service Workers
2. IndexedDB
3. Sincronización offline
4. Testing
5. Optimización

**Total: 14-18 semanas (3.5-4.5 meses)**

---

## 📋 PRÓXIMOS PASOS

1. ✅ **Crear estructura del proyecto** (frontend + backend)
2. ✅ **Setup PostgreSQL** y crear esquema
3. ✅ **Implementar AuthService** y API básica
4. ✅ **Crear frontend** con Login y Dashboard
5. ✅ **Migrar funcionalidades** una por una

---

**¿Empezamos con la estructura del proyecto?**
