# Guía completa: generar instalables CGV Desktop desde cero

Última ejecución: 28 jul 2026 — versión **1.1.0**

> ⚡ **VÍA RÁPIDA:** ejecuta `./regenerar-instalables.sh` desde la raíz del repo y hace TODO automáticamente (limpieza + builds Mac/Linux/Windows + descargas + checksums + firmas GPG). Esta guía queda como referencia manual de cada paso.

Estado actual:
- ✅ 7 instalables generados y firmados con GPG (en `INSTALABLES-FINALES/`)
- ✅ Solicitud enviada a SignPath Foundation (firma Windows gratuita) — **en espera de aprobación**
- 🍎 macOS: sin firma Apple (requiere US$99/año) → usuarios usan "Abrir de todas formas"

---

## PASO 0 — Subir cambios (OBLIGATORIO antes de Linux/Windows)

Los workflows de GitHub compilan desde el **master remoto**, no desde tus archivos locales.

```bash
cd /Users/rarojas/Documents/A_FULLAPP
git add -A
git commit -m "mensaje descriptivo"
git push origin master
```

> 🍎 Mac compila local → usa tus cambios aunque no los subas.
> 💡 Si es una versión nueva, primero sube `"version"` en `desktop/package.json` (ej. `1.2.0`) y ajusta los nombres de artefacto/tag en los comandos de abajo.

---

## 🍎 MAC — compilación LOCAL (~15-20 min c/u)

```bash
cd /Users/rarojas/Documents/A_FULLAPP/desktop

rm -rf dist/*                 # limpiar dist viejo

# Runtime científico: SOLO si cambiaron paquetes R/conda
# npm run runtime:mac:arm64
# npm run runtime:mac:x64     (requiere Rosetta 2)

npm run build:mac:arm64       # Apple Silicon (M1/M2/M3/M4) → DMG + ZIP
npm run build:mac:x64         # Intel → DMG + ZIP

cp dist/CGV-Desktop-1.1.0-macOS-arm64.dmg \
   dist/CGV-Desktop-1.1.0-macOS-arm64.zip \
   dist/CGV-Desktop-1.1.0-macOS-x64.dmg \
   dist/CGV-Desktop-1.1.0-macOS-x64.zip \
   ../INSTALABLES-FINALES/
```

Salida original: `desktop/dist/` (DMG y ZIP, sin firma Apple → usuario: clic derecho → Abrir, o Ajustes → Privacidad y seguridad → "Abrir de todas formas").

---

## 🐧 LINUX — GitHub Actions (~10 min)

```bash
cd /Users/rarojas/Documents/A_FULLAPP

gh workflow run desktop-linux.yml --ref master
gh run list --workflow desktop-linux.yml --branch master --limit 1
#  ↑ anota el ID

gh run watch <ID> --repo raulrojas22/CGV --exit-status

gh run download <ID> --repo raulrojas22/CGV \
  --name CGV-Desktop-Linux-x64-1.1.0 \
  --dir INSTALABLES-FINALES
```

Genera: `CGV-Desktop-1.1.0-Linux-x86_64.AppImage` + `CGV-Desktop-1.1.0-Linux-amd64.deb`

---

## 🪟 WINDOWS — GitHub Actions

### Opción A: SIN firma (la usada hoy, ~33 min)

El workflow intenta firmar con SignPath; sin credenciales falla ESE paso,
pero **el instalador ya quedó construido y probado** y se sube como artefacto:

```bash
gh workflow run desktop-windows-release.yml --ref desktop-v1.1.0
gh run list --workflow desktop-windows-release.yml --limit 1

# Cuando falle en "Submit signing request to SignPath", descarga el artefacto sin firmar:
gh run download <ID> --repo raulrojas22/CGV \
  --name cgv-desktop-windows-unsigned-<ID>-1 \
  --dir INSTALABLES-FINALES
```

> Requiere que exista el tag (debe coincidir con la versión de `desktop/package.json`):
> ```bash
> git tag desktop-v1.1.0
> git push origin desktop-v1.1.0
> ```

Usuario final: SmartScreen → "Más información" → "Ejecutar de todas formas".

### Opción B: CON firma SignPath (cuando aprueben la solicitud)

Configurar credenciales (una sola vez, valores del dashboard de SignPath):

```bash
gh secret set SIGNPATH_API_TOKEN --repo raulrojas22/CGV
gh variable set SIGNPATH_ORGANIZATION_ID --repo raulrojas22/CGV
gh variable set SIGNPATH_PROJECT_SLUG --repo raulrojas22/CGV
gh variable set SIGNPATH_SIGNING_POLICY_SLUG --repo raulrojas22/CGV
gh variable set SIGNPATH_ARTIFACT_CONFIGURATION_SLUG --repo raulrojas22/CGV
```

Y lanzar el MISMO workflow — ahora completará todos los pasos:

```bash
gh workflow run desktop-windows-release.yml --ref desktop-v1.1.0
gh run watch <ID> --repo raulrojas22/CGV --exit-status

gh run download <ID> --repo raulrojas22/CGV \
  --name cgv-desktop-windows-signed-1.1.0 \
  --dir INSTALABLES-FINALES
```

---

## 🔏 FIRMA GPG (Linux + Windows + opcional Mac)

Llave: `CGV (CGV releases) <raulrojas22@icloud.com>`
Huella: `E3A3 3680 8238 E6A3 95C1 6031 01DE 6EB5 0068 0FDF` (expira 2028-07-27)

```bash
cd /Users/rarojas/Documents/A_FULLAPP/INSTALABLES-FINALES

gpg --armor --detach-sign CGV-Desktop-1.1.0-Linux-x86_64.AppImage
gpg --armor --detach-sign CGV-Desktop-1.1.0-Linux-amd64.deb
gpg --armor --detach-sign CGV-Desktop-1.1.0-Windows-x64-Setup.exe
# Opcional Mac:
# gpg --armor --detach-sign CGV-Desktop-1.1.0-macOS-arm64.dmg   (y los demás)

shasum -a 256 *.AppImage *.deb *.exe > SHA256SUMS.txt
gpg --armor --detach-sign SHA256SUMS.txt
```

Exportar llave pública para publicar (ya existe: `CGV-GPG-public-key.asc`):

```bash
gpg --armor --export raulrojas22@icloud.com > CGV-GPG-public-key.asc
```

⚠️ **RESPALDO de la llave privada** (si se pierde, no podrás firmar con la misma identidad):

```bash
gpg --export-secret-keys --armor raulrojas22@icloud.com > ~/cgv-gpg-PRIVADA-backup.asc
# guardar en lugar seguro (USB/gestor contraseñas) y borrar del home
```

### Verificación (lo que hace el usuario)

```bash
gpg --import CGV-GPG-public-key.asc
gpg --verify <archivo>.asc <archivo>     # debe decir "Good signature"
shasum -a 256 -c SHA256SUMS.txt          # debe decir OK
```

---

## 🧹 LIMPIEZA de versiones viejas

### Local

```bash
rm -rf /Users/rarojas/Documents/A_FULLAPP/desktop/dist/*
rm -rf /Users/rarojas/Documents/A_FULLAPP/INSTALABLES-FINALES/*
```

### GitHub (borra runs viejos y sus artefactos)

```bash
gh run list --repo raulrojas22/CGV --limit 50 --json databaseId --jq '.[].databaseId' \
  | while read -r id; do
      gh api repos/raulrojas22/CGV/actions/runs/$id -X DELETE
    done
```

### Tag viejo (para reusar el mismo número de versión)

```bash
git push origin --delete desktop-v1.1.0
git tag -d desktop-v1.1.0
```

---

## ⏭️ CHECKLIST PARA LA PRÓXIMA VERSIÓN (ej. 1.2.0)

**Automático:** cambia la versión, sube todo, y ejecuta `./regenerar-instalables.sh` (pasos 2-7 de una vez).

**Manual:**
1. [ ] Cambiar `"version": "1.2.0"` en `desktop/package.json`
2. [ ] `git add -A && git commit && git push origin master`
3. [ ] Mac: `cd desktop && rm -rf dist/* && npm run build:mac:arm64 && npm run build:mac:x64` → copiar a `INSTALABLES-FINALES/`
4. [ ] Linux: `gh workflow run desktop-linux.yml --ref master` → descargar artefacto `CGV-Desktop-Linux-x64-1.2.0`
5. [ ] Windows: `git tag desktop-v1.2.0 && git push origin desktop-v1.2.0` → `gh workflow run desktop-windows-release.yml --ref desktop-v1.2.0` → descargar
6. [ ] Firmar todo con GPG + regenerar `SHA256SUMS.txt` firmado
7. [ ] Verificar: `ls -la INSTALABLES-FINALES/` → 7 instalables + firmas `.asc`
