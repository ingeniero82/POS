# 📚 LECCIÓN 1.1: ¿QUÉ ES NODE.JS?
## Tu Primera Lección - Fundamentos

---

## 🎯 OBJETIVOS DE ESTA LECCIÓN

Al final de esta lección, podrás:

1. ✅ Explicar qué es Node.js (con tus palabras)
2. ✅ Entender por qué lo necesitamos
3. ✅ Crear tu primer programa Node.js
4. ✅ Ejecutar código JavaScript en el servidor

---

## 📖 PARTE 1: EXPLICACIÓN CONCEPTUAL

### **¿Qué es Node.js?**

**Respuesta corta:** Node.js es JavaScript que corre en el servidor (en tu computadora, no en el navegador).

**Respuesta larga:**

#### **JavaScript Normal (en el Navegador):**
```
Usuario → Navegador → JavaScript → Página Web
```

JavaScript normalmente solo funciona en el navegador (Chrome, Firefox, etc.).

#### **Node.js (en el Servidor):**
```
Usuario → Servidor → Node.js → Respuesta
```

Node.js permite que JavaScript corra en tu computadora (servidor), no solo en el navegador.

---

### **¿Por qué Node.js?**

#### **Problema Antes de Node.js:**
- **Frontend:** JavaScript (navegador)
- **Backend:** Otro lenguaje (Python, Java, PHP, etc.)
- **Resultado:** Dos lenguajes diferentes, más complejo

#### **Solución con Node.js:**
- **Frontend:** JavaScript (navegador)
- **Backend:** JavaScript (Node.js)
- **Resultado:** Mismo lenguaje, más simple

**Ventaja:** Aprendes un solo lenguaje (JavaScript) y lo usas en ambos lados.

---

### **¿Cómo Funciona Node.js?**

**Analogía Simple:**

Imagina que JavaScript es un idioma:
- **Antes:** Solo se hablaba en el navegador (como hablar solo en casa)
- **Ahora:** Se habla en el servidor también (como hablar en casa Y en el trabajo)

**Node.js = JavaScript + Motor V8 (de Chrome) + Librerías para Servidor**

---

### **¿Qué Puede Hacer Node.js?**

1. ✅ **Crear servidores web** (como Apache, pero con JavaScript)
2. ✅ **Conectar con bases de datos** (PostgreSQL, MySQL, etc.)
3. ✅ **Procesar archivos** (leer, escribir, modificar)
4. ✅ **Comunicarse con otras aplicaciones** (APIs, servicios)
5. ✅ **Mucho más...**

---

## 🔧 PARTE 2: VERIFICAR INSTALACIÓN

### **Paso 1: Verificar que Node.js está Instalado**

Abre tu terminal/consola (PowerShell o CMD) y escribe:

```bash
node --version
```

**¿Qué deberías ver?**
- Algo como: `v20.11.0` o `v18.19.0`
- Si ves un número de versión: ✅ **Node.js está instalado**
- Si ves un error: ❌ **Necesitamos instalarlo**

**¿Qué hacer si no está instalado?**
1. Ir a: https://nodejs.org/
2. Descargar la versión LTS (Long Term Support)
3. Instalar (siguiente, siguiente, siguiente)
4. Reiniciar terminal
5. Probar `node --version` de nuevo

---

### **Paso 2: Verificar que npm está Instalado**

npm (Node Package Manager) viene con Node.js. Verifica:

```bash
npm --version
```

**¿Qué deberías ver?**
- Algo como: `10.2.4` o `9.9.0`
- Si ves un número: ✅ **npm está instalado**

**npm es importante porque:**
- Instala librerías (como paquetes en Flutter)
- Gestiona dependencias del proyecto
- Lo usaremos mucho

---

## 💻 PARTE 3: TU PRIMER PROGRAMA

### **Paso 1: Crear Carpeta del Proyecto**

En tu terminal, navega a donde quieres crear el proyecto:

```bash
cd D:\losoft
mkdir smart_seller_web
cd smart_seller_web
```

**¿Qué hicimos?**
- `cd D:\losoft` - Ir a la carpeta losoft
- `mkdir smart_seller_web` - Crear carpeta nueva
- `cd smart_seller_web` - Entrar a la carpeta

---

### **Paso 2: Crear tu Primer Archivo**

Abre VS Code en esta carpeta:

```bash
code .
```

**¿Qué hace `code .`?**
- Abre VS Code en la carpeta actual
- El punto (`.`) significa "carpeta actual"

**Alternativa:** Abrir VS Code manualmente y abrir la carpeta `smart_seller_web`

---

### **Paso 3: Crear Archivo JavaScript**

En VS Code, crea un archivo nuevo:
- Nombre: `hola-mundo.js`
- Ubicación: Dentro de la carpeta `smart_seller_web`

**Escribe esto en el archivo:**

```javascript
console.log("Hola Mundo desde Node.js!");
```

**¿Qué hace este código?**
- `console.log()` - Imprime algo en la consola
- `"Hola Mundo desde Node.js!"` - El mensaje que queremos mostrar

**Explicación línea por línea:**
1. `console` - Objeto que permite interactuar con la consola
2. `.log()` - Método que imprime algo
3. `("Hola Mundo desde Node.js!")` - El mensaje que queremos imprimir

---

### **Paso 4: Ejecutar tu Programa**

En la terminal (asegúrate de estar en la carpeta `smart_seller_web`):

```bash
node hola-mundo.js
```

**¿Qué deberías ver?**
```
Hola Mundo desde Node.js!
```

**¡Felicidades! 🎉 Acabas de ejecutar tu primer programa Node.js**

---

## 🎓 PARTE 4: ENTENDER LO QUE ACABAMOS DE HACER

### **¿Qué Pasó?**

1. **Creamos un archivo JavaScript** (`hola-mundo.js`)
2. **Escribimos código JavaScript** (`console.log()`)
3. **Ejecutamos con Node.js** (`node hola-mundo.js`)
4. **Vimos el resultado** en la terminal

### **¿Por qué es Diferente a JavaScript en el Navegador?**

**JavaScript en el Navegador:**
- Necesitas un archivo HTML
- Abres el HTML en el navegador
- El navegador ejecuta el JavaScript

**Node.js:**
- Solo necesitas el archivo `.js`
- Ejecutas directamente con `node`
- No necesitas navegador

---

## 🧪 PARTE 5: EXPERIMENTAR

### **Ejercicio 1: Modificar el Mensaje**

Cambia el mensaje en `hola-mundo.js`:

```javascript
console.log("¡Mi primer programa Node.js funciona!");
```

Ejecuta de nuevo:
```bash
node hola-mundo.js
```

**¿Qué aprendiste?**
- Puedes modificar el código
- Ejecutas de nuevo y ves el cambio

---

### **Ejercicio 2: Múltiples Mensajes**

Agrega más líneas:

```javascript
console.log("Hola Mundo desde Node.js!");
console.log("Esta es mi segunda línea");
console.log("Node.js es genial!");
```

Ejecuta:
```bash
node hola-mundo.js
```

**¿Qué deberías ver?**
```
Hola Mundo desde Node.js!
Esta es mi segunda línea
Node.js es genial!
```

**¿Qué aprendiste?**
- Puedes tener múltiples `console.log()`
- Se ejecutan en orden (de arriba hacia abajo)

---

### **Ejercicio 3: Variables**

Modifica el código:

```javascript
let mensaje = "Hola desde Node.js!";
console.log(mensaje);
```

**¿Qué hace esto?**
- `let mensaje` - Crea una variable llamada "mensaje"
- `= "Hola desde Node.js!"` - Le asigna un valor
- `console.log(mensaje)` - Imprime el valor de la variable

**Ejecuta:**
```bash
node hola-mundo.js
```

**¿Qué aprendiste?**
- Puedes guardar valores en variables
- Puedes usar variables en lugar de escribir el texto directamente

---

## 📝 PARTE 6: REPASO

### **Conceptos Clave:**

1. **Node.js** = JavaScript que corre en el servidor
2. **npm** = Gestor de paquetes (viene con Node.js)
3. **console.log()** = Imprime algo en la consola
4. **node archivo.js** = Ejecuta un archivo JavaScript

### **Lo que Aprendiste:**

✅ Node.js permite usar JavaScript en el servidor
✅ Puedes crear archivos `.js` y ejecutarlos con `node`
✅ `console.log()` imprime mensajes
✅ Puedes usar variables para guardar valores

---

## ❓ PREGUNTAS FRECUENTES

### **"¿Node.js es un lenguaje de programación?"**
No, Node.js es un **runtime** (entorno de ejecución). El lenguaje es **JavaScript**.

### **"¿Necesito saber JavaScript antes?"**
No necesariamente, pero ayuda. Si no sabes JavaScript, lo aprenderemos juntos.

### **"¿Por qué se llama Node.js?"**
"Node" = nodo (punto de conexión), "js" = JavaScript. Es un "nodo" que ejecuta JavaScript.

### **"¿Node.js es solo para servidores?"**
Principalmente sí, pero también puedes usarlo para scripts, herramientas, etc.

---

## 🎯 EVALUACIÓN

**Pregúntate:**

1. ¿Puedo explicar qué es Node.js? (con mis palabras)
2. ¿Puedo crear un archivo `.js` y ejecutarlo?
3. ¿Entiendo qué hace `console.log()`?
4. ¿Puedo modificar el código y que funcione?

**Si la respuesta es SÍ a todas:**
✅ **¡Avanzamos a la siguiente parte!**

**Si la respuesta es NO a alguna:**
- Repasa esa parte
- Haz más ejercicios
- Pregunta dudas
- **NO avanzamos hasta que entiendas**

---

## 🚀 PRÓXIMO PASO

**Cuando estés listo:**
- Lección 1.2: Variables y Tipos de Datos en JavaScript
- O si prefieres, más práctica con Node.js

**¿Listo para continuar?** 🎓
