# CGeV Desktop 1.2.0: build y publicación paso a paso

Esta guía genera y publica los instaladores nuevos con identidad visible
`CGeV Desktop`. No cambia los identificadores de compatibilidad:

- paquete Electron: `cgv-desktop`;
- app ID: `org.cgv.desktop`;
- repositorio fuente: `raulrojas22/CGV`;
- repositorio de actualizaciones: `raulrojas22/CGV-Desktop-Releases`;
- datos y configuración: carpeta histórica `CGV Desktop` en cada sistema;
- variables, eventos y rutas internas: `CGV_*` y `cgv-*`.

Los instaladores históricos no se renombran. Desde 1.2.0, los archivos nuevos
se llaman `CGeV-Desktop-*`.

## 1. Preparar la versión

```bash
cd /path/to/CGeV
git switch master
git pull --ff-only origin master
npm --prefix desktop ci
npm --prefix desktop test
npm --prefix desktop run verify:config
Rscript scripts/test_cgev_visible_identity.R
node scripts/test_desktop_release_publication_static.js
```

Confirma versión, nombre visible e identificador estable:

```bash
node -p "require('./desktop/package.json').version"
node -p "require('./desktop/package.json').build.productName"
node -p "require('./desktop/package.json').build.appId"
```

La salida esperada es `1.2.0`, `CGeV Desktop` y `org.cgv.desktop`.

Revisa, commitea y sube los cambios. No uses `git add -A` sin revisar, porque
el repositorio puede contener trabajo no relacionado:

```bash
git status --short
git diff --check
git add <archivos-revisados>
git commit -m "Adopt CGeV Desktop system identity"
git push origin master
```

## 2. Ruta automática recomendada

El script construye macOS localmente, lanza Linux y Windows en GitHub Actions,
descarga los resultados, calcula SHA-256 y crea firmas GPG. Además, el workflow
firmado de Windows crea o actualiza el draft `v1.2.0`:

```bash
cd /path/to/CGeV
CREATE_RELEASE_DRAFT=1 ./desktop/scripts/regenerar-instalables.sh
```

El script crea el tag inmutable `desktop-v1.2.0`. Si ya apunta a otro commit, se
detendrá: incrementa la versión; no muevas ni reutilices tags ya construidos.

La salida queda en:

```text
/path/to/CGeV/INSTALABLES-FINALES/
```

## 3. Comandos manuales por plataforma

Usa esta sección para repetir una plataforma de forma independiente.

### macOS arm64 y x64

Los runtimes sólo se reconstruyen cuando cambian R, paquetes científicos o
dependencias nativas. En Apple Silicon, el runtime x64 requiere Rosetta 2.

```bash
cd /path/to/CGeV/desktop
npm ci

# Sólo si cambió el runtime científico:
npm run runtime:mac:arm64
npm run runtime:mac:x64

npm run build:mac:arm64
npm run build:mac:x64

shasum -a 256 \
  dist/CGeV-Desktop-1.2.0-macOS-arm64.dmg \
  dist/CGeV-Desktop-1.2.0-macOS-arm64.zip \
  dist/CGeV-Desktop-1.2.0-macOS-x64.dmg \
  dist/CGeV-Desktop-1.2.0-macOS-x64.zip
```

### Linux x64

```bash
cd /path/to/CGeV

gh workflow run desktop-linux.yml --repo raulrojas22/CGV --ref master
gh run list --repo raulrojas22/CGV --workflow desktop-linux.yml --branch master --limit 3
gh run watch <RUN_ID> --repo raulrojas22/CGV --exit-status

gh run download <RUN_ID> \
  --repo raulrojas22/CGV \
  --name CGeV-Desktop-Linux-x64-1.2.0 \
  --dir INSTALABLES-FINALES
```

### Windows x64 firmado

El tag debe coincidir exactamente con `desktop/package.json`:

```bash
cd /path/to/CGeV
git tag desktop-v1.2.0
git push origin desktop-v1.2.0

gh workflow run desktop-windows-release.yml \
  --repo raulrojas22/CGV \
  --ref desktop-v1.2.0 \
  -f create_release_draft=true

gh run list --repo raulrojas22/CGV --workflow desktop-windows-release.yml --limit 3
gh run watch <RUN_ID> --repo raulrojas22/CGV --exit-status

gh run download <RUN_ID> \
  --repo raulrojas22/CGV \
  --name cgv-desktop-windows-signed-1.2.0 \
  --dir INSTALABLES-FINALES
```

La solicitud puede esperar aprobación en SignPath. El EXE público no debe
publicarse si Authenticode no devuelve `Valid`. El workflow valida la firma y
regenera `latest.yml` y el blockmap desde los bytes ya firmados.

## 4. Completar el draft de GitHub

```bash
gh release view v1.2.0 \
  --repo raulrojas22/CGV-Desktop-Releases \
  --json name,isDraft,assets,url
```

Windows ya se sube desde el workflow. Agrega los demás instaladores y reemplaza
el checksum parcial por el conjunto final:

```bash
cd /path/to/CGeV

gh release upload v1.2.0 \
  --repo raulrojas22/CGV-Desktop-Releases \
  --clobber \
  INSTALABLES-FINALES/CGeV-Desktop-1.2.0-macOS-arm64.dmg \
  INSTALABLES-FINALES/CGeV-Desktop-1.2.0-macOS-arm64.zip \
  INSTALABLES-FINALES/CGeV-Desktop-1.2.0-macOS-x64.dmg \
  INSTALABLES-FINALES/CGeV-Desktop-1.2.0-macOS-x64.zip \
  INSTALABLES-FINALES/CGeV-Desktop-1.2.0-Linux-x86_64.AppImage \
  INSTALABLES-FINALES/CGeV-Desktop-1.2.0-Linux-amd64.deb \
  INSTALABLES-FINALES/CGeV-Desktop-1.2.0-Windows-x64-Setup.exe \
  INSTALABLES-FINALES/CGeV-Desktop-1.2.0-Windows-x64-Setup.exe.blockmap \
  INSTALABLES-FINALES/latest.yml \
  INSTALABLES-FINALES/latest-linux.yml \
  INSTALABLES-FINALES/SHA256SUMS.txt \
  INSTALABLES-FINALES/SHA256SUMS.txt.asc \
  INSTALABLES-FINALES/CGV-GPG-public-key.asc
```

Mantén el draft privado hasta terminar las pruebas. Luego:

```bash
gh release edit v1.2.0 \
  --repo raulrojas22/CGV-Desktop-Releases \
  --title "CGeV Desktop 1.2.0" \
  --notes-file desktop/RELEASE_NOTES_v1.2.0.md

gh release edit v1.2.0 \
  --repo raulrojas22/CGV-Desktop-Releases \
  --draft=false \
  --latest
```

## 5. Preparar y subir las descargas visibles a Oracle

Oracle sirve los cinco instaladores visibles. GitHub conserva el canal de
actualización de Windows y los artefactos técnicos.

```bash
cd /path/to/CGeV
./scripts/preparar-publicacion-desktop.sh --check
./scripts/preparar-publicacion-desktop.sh
```

Esto crea `desktop/oracle-upload-1.2.0/`. En Oracle Object Storage sube:

1. Instaladores, firmas, checksums y llave GPG.
2. `desktop-release.json` al final.

No subas `logs/`, ZIP de macOS ni `latest*.yml` a este canal web.

Con Oracle CLI, sustituye los valores antes de ejecutar:

```bash
OCI_NAMESPACE="TU_NAMESPACE"
OCI_BUCKET="TU_BUCKET"
OCI_PREFIX="cgv-desktop"
UPLOAD_DIR="/path/to/CGeV/desktop/oracle-upload-1.2.0"

oci os object bulk-upload \
  --namespace-name "$OCI_NAMESPACE" \
  --bucket-name "$OCI_BUCKET" \
  --src-dir "$UPLOAD_DIR" \
  --object-prefix "$OCI_PREFIX/" \
  --exclude "desktop-release.json" \
  --verify-checksum \
  --overwrite

oci os object put \
  --namespace-name "$OCI_NAMESPACE" \
  --bucket-name "$OCI_BUCKET" \
  --name "$OCI_PREFIX/desktop-release.json" \
  --file "$UPLOAD_DIR/desktop-release.json" \
  --force
```

## 6. Pruebas obligatorias

- Instalar 1.1.0, crear datos/sesión/caché y actualizar a 1.2.0 en Windows.
- Confirmar `CGeV Desktop.exe` y lectura de `%LOCALAPPDATA%\CGV Desktop`.
- Confirmar que desinstalar no elimina el workspace seleccionado.
- Probar instalación limpia en Windows 10/11, macOS arm64/x64 y Linux.
- Comprobar que los botones web descargan nombres `CGeV-Desktop-*`.
- Verificar SHA-256, firmas GPG y Authenticode de Windows.
- Mantener 1.1.0 y sus archivos históricos disponibles durante la transición.

La matriz detallada está en `desktop/WINDOWS_TEST_CHECKLIST.md`.
