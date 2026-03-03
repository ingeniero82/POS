# Generar ejecutable para el cliente — Smart Seller POS

Un solo proceso. Proyecto **SmartSeller_POS_v1.0_DNPA** y su script de Inno.

---

## Paso 1 — Compilar la app (terminal de Cursor)

Ejecutar en este orden:

```powershell
cd d:\losoft\DEMOV2\smart_seller\SmartSeller_POS_v1.0_DNPA
```

```powershell
flutter clean
```

```powershell
flutter pub get
```

```powershell
flutter build windows --release
```

Esperar a que termine. El resultado queda en:
`SmartSeller_POS_v1.0_DNPA\build\windows\x64\runner\Release\`

---

## Paso 2 — Generar el instalador (Inno Setup)

1. Abrir **Inno Setup Compiler**.
2. **File → Open**.
3. Abrir este archivo:
   ```
   d:\losoft\DEMOV2\smart_seller\SmartSeller_POS_v1.0_DNPA\installer\SmartSeller_Setup.iss
   ```
4. Pulsar **F9**.

---

## Paso 3 — Dónde queda el instalador

El ejecutable para el cliente queda en:

```
d:\losoft\DEMOV2\smart_seller\SmartSeller_POS_v1.0_DNPA\output\SmartSeller_POS_Setup_v1.0.0.exe
```

Ese es el archivo que se entrega al cliente.

---

## Resumen

| Paso | Acción |
|------|--------|
| 1 | Terminal: `cd` a DNPA → `flutter clean` → `flutter pub get` → `flutter build windows --release` |
| 2 | Inno: abrir `SmartSeller_POS_v1.0_DNPA\installer\SmartSeller_Setup.iss` → **F9** |
| 3 | Instalador listo en `SmartSeller_POS_v1.0_DNPA\output\` |
