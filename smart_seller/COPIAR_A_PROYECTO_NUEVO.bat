@echo off
title Copiar Documentos a Proyecto Nuevo
color 0B

echo.
echo ========================================
echo    COPIAR DOCUMENTOS A PROYECTO NUEVO
echo ========================================
echo.

REM Ruta de destino fija
set DESTINO=D:\losoft\migrartecnologia
echo Ruta de destino: %DESTINO%

REM Verificar que la carpeta existe o crearla
if not exist "%DESTINO%" (
    echo.
    echo Creando carpeta: %DESTINO%
    mkdir "%DESTINO%"
    mkdir "%DESTINO%\documentacion"
    mkdir "%DESTINO%\documentacion\arquitectura"
    mkdir "%DESTINO%\documentacion\aprendizaje"
    mkdir "%DESTINO%\documentacion\lecciones"
) else (
    echo.
    echo La carpeta ya existe. Creando subcarpetas...
    if not exist "%DESTINO%\documentacion" mkdir "%DESTINO%\documentacion"
    if not exist "%DESTINO%\documentacion\arquitectura" mkdir "%DESTINO%\documentacion\arquitectura"
    if not exist "%DESTINO%\documentacion\aprendizaje" mkdir "%DESTINO%\documentacion\aprendizaje"
    if not exist "%DESTINO%\documentacion\lecciones" mkdir "%DESTINO%\documentacion\lecciones"
)

echo.
echo [1/4] Copiando documentos principales...
copy /Y "CONTEXTO_COMPLETO_PROYECTO.md" "%DESTINO%\" >nul
copy /Y "PROMPT_CONTINUAR_PROYECTO.txt" "%DESTINO%\" >nul
copy /Y "README_PROYECTO_NUEVO.md" "%DESTINO%\" >nul
echo ✓ Documentos principales copiados

echo.
echo [2/4] Copiando documentación de arquitectura...
copy /Y "ARQUITECTURA_NUEVO_PROYECTO.md" "%DESTINO%\documentacion\arquitectura\" >nul
copy /Y "PLAN_MIGRACION_TECNOLOGIA.md" "%DESTINO%\documentacion\arquitectura\" >nul
copy /Y "ANALISIS_TECNOLOGIA_CORRECTA.md" "%DESTINO%\documentacion\arquitectura\" >nul
copy /Y "POR_QUE_ESTA_TECNOLOGIA_ES_CORRECTA.md" "%DESTINO%\documentacion\arquitectura\" >nul
echo ✓ Arquitectura copiada

echo.
echo [3/4] Copiando documentación de aprendizaje...
copy /Y "PLAN_APRENDIZAJE_PASO_A_PASO.md" "%DESTINO%\documentacion\aprendizaje\" >nul
copy /Y "GUIA_ESTUDIANTE.md" "%DESTINO%\documentacion\aprendizaje\" >nul
copy /Y "CHECKLIST_MAÑANA.md" "%DESTINO%\documentacion\aprendizaje\" >nul
copy /Y "BIENVENIDA_MAÑANA.md" "%DESTINO%\documentacion\aprendizaje\" >nul
echo ✓ Aprendizaje copiado

echo.
echo [4/4] Copiando lecciones...
copy /Y "LECCION_1.1_QUE_ES_NODEJS.md" "%DESTINO%\documentacion\lecciones\" >nul
echo ✓ Lecciones copiadas

echo.
echo ========================================
echo    DOCUMENTOS COPIADOS EXITOSAMENTE
echo ========================================
echo.
echo Ubicación: %DESTINO%
echo.
echo Estructura creada:
echo   %DESTINO%\
echo   ├── CONTEXTO_COMPLETO_PROYECTO.md
echo   ├── PROMPT_CONTINUAR_PROYECTO.txt
echo   ├── README_PROYECTO_NUEVO.md
echo   └── documentacion\
echo       ├── arquitectura\
echo       ├── aprendizaje\
echo       └── lecciones\
echo.
echo Próximo paso: Abre README_PROYECTO_NUEVO.md
echo.
pause
