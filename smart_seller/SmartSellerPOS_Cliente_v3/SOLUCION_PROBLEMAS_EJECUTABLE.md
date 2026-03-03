# Solución de Problemas - Smart Seller POS

## Problema: El ejecutable no abre

### Solución 1: Dependencias faltantes
1. Ejecutar `INSTALAR_DEPENDENCIAS.bat` como administrador
2. Reiniciar el equipo
3. Intentar abrir `smart_seller.exe` nuevamente

### Solución 2: Windows Defender bloquea la aplicación
1. Abrir Windows Defender
2. Ir a "Configuración" > "Exclusiones"
3. Agregar la carpeta de la aplicación como exclusión
4. O ejecutar `INSTALAR_COMPLETO.bat` como administrador

### Solución 3: Permisos insuficientes
1. Hacer clic derecho en `smart_seller.exe`
2. Seleccionar "Ejecutar como administrador"
3. Si funciona, ejecutar `INSTALAR.bat` para configurar permisos

### Solución 4: Archivos corruptos
1. Descargar nuevamente el ZIP
2. Extraer en una nueva carpeta
3. Ejecutar `INSTALAR_COMPLETO.bat`

## Problema: Error de DLL faltante

### Solución:
1. Ejecutar `INSTALAR_DEPENDENCIAS.bat`
2. Verificar que Visual C++ Redistributable esté instalado
3. Reiniciar el equipo

## Problema: La aplicación se cierra inesperadamente

### Solución:
1. Verificar que no haya otro proceso de Smart Seller ejecutándose
2. Ejecutar como administrador
3. Verificar espacio en disco (mínimo 2GB libre)

## Contacto de Soporte
Si los problemas persisten, contactar al equipo de desarrollo con:
- Versión de Windows
- Mensaje de error exacto
- Pasos para reproducir el problema
