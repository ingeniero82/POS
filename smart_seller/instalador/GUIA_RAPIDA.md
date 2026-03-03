# 🚀 Guía Rápida - Crear Instalador para Cliente

## Pasos Rápidos (5 minutos)

### 1. Instalar Inno Setup (Solo la primera vez)
- Descargar: https://jrsoftware.org/isdl.php
- Instalar versión 6.2 o superior
- ✅ Asegurarse de instalar "Inno Setup Preprocessor" durante la instalación

### 2. Compilar la Aplicación
```bash
flutter clean
flutter pub get
flutter build windows --release
```

### 3. Crear el Instalador
Ejecutar como administrador:
```batch
instalador\crear_instalador.bat
```

### 4. Distribuir
El instalador estará en: `dist\SmartSellerPOS_Setup_v2.0.exe`

---

## ✅ Verificación Rápida

Antes de entregar al cliente, verificar:

- [ ] El archivo `SmartSellerPOS_Setup_v2.0.exe` existe en `dist\`
- [ ] El tamaño es razonable (50-200 MB)
- [ ] Probar instalación en una máquina de prueba
- [ ] La aplicación inicia correctamente después de instalar

---

## 🔧 Si Algo Sale Mal

### Error: "Inno Setup no encontrado"
- Verificar que Inno Setup esté instalado
- Editar `crear_instalador.bat` y cambiar la ruta si es necesario

### Error: "No se encontró el ejecutable"
- Ejecutar primero: `flutter build windows --release`
- Verificar que existe: `build\windows\x64\runner\Release\smart_seller.exe`

### El instalador no funciona en el cliente
- Verificar que el cliente tenga Windows 10/11 (64-bit)
- Ejecutar como administrador
- Revisar `SOLUCION_PROBLEMAS_EJECUTABLE.md`

---

## 📞 Soporte

Para más detalles, ver: `instalador\LEEME_INSTALADOR.md`


