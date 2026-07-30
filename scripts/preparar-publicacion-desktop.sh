#!/usr/bin/env bash
#
# Convierte INSTALABLES-FINALES/ en un paquete público mínimo y verificable
# para Oracle Object Storage.
#
# Flujo normal:
#   1. ./regenerar-instalables.sh
#   2. ./scripts/preparar-publicacion-desktop.sh
#   3. Subir TODO el contenido de desktop/oracle-upload-VERSION/ a Oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DESKTOP_DIR="$ROOT_DIR/desktop"
FINAL_DIR="$ROOT_DIR/INSTALABLES-FINALES"
CONFIG_FILE="$ROOT_DIR/www/desktop-release-source.json"
GPG_ID="${CGV_GPG_ID:-raulrojas22@icloud.com}"
MIN_BYTES=$((5 * 1024 * 1024))

CHECK_ONLY=0
OVERRIDE_BASE_URL=""

say() {
  printf '\n== %s ==\n' "$*"
}

ok() {
  printf '✓ %s\n' "$*"
}

warn() {
  printf '⚠ %s\n' "$*" >&2
}

die() {
  printf '✗ %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/preparar-publicacion-desktop.sh [opciones]

Opciones:
  --check                       Validar sin copiar ni firmar.
  --base-url URL                Usar esta URL base sin modificar la configuración.
  -h, --help                    Mostrar esta ayuda.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)
      CHECK_ONLY=1
      shift
      ;;
    --base-url)
      [ "$#" -ge 2 ] || die "Falta la URL después de --base-url."
      OVERRIDE_BASE_URL="${2%/}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Opción desconocida: $1"
      ;;
  esac
done

command -v node >/dev/null 2>&1 || die "Falta Node.js."
command -v shasum >/dev/null 2>&1 || die "Falta shasum."
[ -d "$FINAL_DIR" ] || die "No existe $FINAL_DIR. Ejecuta ./regenerar-instalables.sh primero."
[ -f "$CONFIG_FILE" ] || die "No existe $CONFIG_FILE."

VERSION="$(node -p "require('$DESKTOP_DIR/package.json').version")"

if [ -n "$OVERRIDE_BASE_URL" ]; then
  case "$OVERRIDE_BASE_URL" in
    */desktop-release.json) BASE_URL="${OVERRIDE_BASE_URL%/desktop-release.json}" ;;
    *) BASE_URL="$OVERRIDE_BASE_URL" ;;
  esac
else
  MANIFEST_URL="$(node -e '
    const config = require(process.argv[1]);
    process.stdout.write(String(config.manifestUrl || ""));
  ' "$CONFIG_FILE")"
  [ -n "$MANIFEST_URL" ] || die "Primero configura Oracle con ./scripts/configurar-url-oracle-desktop.sh <URL-base>."
  case "$MANIFEST_URL" in
    */desktop-release.json) BASE_URL="${MANIFEST_URL%/desktop-release.json}" ;;
    *) die "manifestUrl debe terminar en /desktop-release.json: $MANIFEST_URL" ;;
  esac
fi

case "$BASE_URL" in
  https://*) ;;
  *) die "La URL base debe comenzar con https://";;
esac

ASSET_SPECS=(
  "mac-arm64|CGV-Desktop-$VERSION-macOS-arm64.dmg"
  "mac-x64|CGV-Desktop-$VERSION-macOS-x64.dmg"
  "linux-appimage|CGV-Desktop-$VERSION-Linux-x86_64.AppImage"
  "linux-deb|CGV-Desktop-$VERSION-Linux-amd64.deb"
  "windows-x64|CGV-Desktop-$VERSION-Windows-x64-Setup.exe"
)

say "Validando artefactos de CGV Desktop $VERSION"
for spec in "${ASSET_SPECS[@]}"; do
  filename="${spec#*|}"
  path="$FINAL_DIR/$filename"
  [ -f "$path" ] || die "Falta el artefacto requerido: $filename"
  bytes="$(stat -f '%z' "$path" 2>/dev/null || stat -c '%s' "$path")"
  [ "$bytes" -ge "$MIN_BYTES" ] || die "$filename parece incompleto ($bytes bytes)."
  ok "$filename ($bytes bytes)"
done

if [ -f "$FINAL_DIR/SHA256SUMS.txt" ]; then
  say "Comprobando los checksums generados por el build"
  (
    cd "$FINAL_DIR"
    shasum -a 256 -c SHA256SUMS.txt
  )
else
  warn "No existe SHA256SUMS.txt en la carpeta bruta; el paquete público generará uno nuevo."
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  say "Validación terminada"
  printf 'URL base: %s\n' "$BASE_URL"
  printf 'Se prepararían %s instaladores públicos.\n' "${#ASSET_SPECS[@]}"
  exit 0
fi

command -v gpg >/dev/null 2>&1 || die "Falta GPG para verificar o crear firmas .asc."
gpg --list-secret-keys "$GPG_ID" >/dev/null 2>&1 \
  || die "No está disponible la llave privada GPG de $GPG_ID."

OUTPUT_DIR="$DESKTOP_DIR/oracle-upload-$VERSION"
TEMP_STAGE="$(mktemp -d "$DESKTOP_DIR/.oracle-upload-$VERSION.XXXXXX")"
cleanup() {
  rm -rf "$TEMP_STAGE"
}
trap cleanup EXIT

say "Preparando carpeta pública"
for spec in "${ASSET_SPECS[@]}"; do
  filename="${spec#*|}"
  source_file="$FINAL_DIR/$filename"
  staged_file="$TEMP_STAGE/$filename"
  cp -p "$source_file" "$staged_file"

  if [ -f "$source_file.asc" ]; then
    gpg --verify "$source_file.asc" "$source_file" >/dev/null 2>&1 \
      || die "La firma existente no corresponde a $filename."
    cp -p "$source_file.asc" "$staged_file.asc"
    ok "Firma verificada: $filename.asc"
  else
    warn "Falta $filename.asc; se generará ahora en el paquete público."
    gpg --armor --detach-sign --local-user "$GPG_ID" \
      --output "$staged_file.asc" "$staged_file"
    ok "Firma creada: $filename.asc"
  fi
done

say "Generando checksum público y firma"
(
  cd "$TEMP_STAGE"
  : > SHA256SUMS.txt
  for spec in "${ASSET_SPECS[@]}"; do
    filename="${spec#*|}"
    shasum -a 256 "$filename" >> SHA256SUMS.txt
  done
)
gpg --armor --detach-sign --local-user "$GPG_ID" \
  --output "$TEMP_STAGE/SHA256SUMS.txt.asc" "$TEMP_STAGE/SHA256SUMS.txt"
gpg --armor --export "$GPG_ID" > "$TEMP_STAGE/CGV-GPG-public-key.asc"
[ -s "$TEMP_STAGE/CGV-GPG-public-key.asc" ] || die "No se pudo exportar la llave pública GPG."

say "Generando desktop-release.json"
NODE_ASSETS=()
for spec in "${ASSET_SPECS[@]}"; do
  NODE_ASSETS+=("$spec")
done

node - "$TEMP_STAGE" "$BASE_URL" "$VERSION" "${NODE_ASSETS[@]}" <<'NODE'
const fs = require("fs");
const path = require("path");

const stageDir = process.argv[2];
const baseUrl = process.argv[3].replace(/\/+$/, "");
const version = process.argv[4];
const specs = process.argv.slice(5);

function publicUrl(fileName) {
  return `${baseUrl}/${encodeURIComponent(fileName)}`;
}

const checksumLines = fs.readFileSync(path.join(stageDir, "SHA256SUMS.txt"), "utf8")
  .trim()
  .split(/\r?\n/);
const checksums = {};
for (const line of checksumLines) {
  const match = line.match(/^([a-f0-9]{64})\s+(.+)$/i);
  if (!match) throw new Error(`Invalid SHA256SUMS line: ${line}`);
  checksums[match[2]] = match[1].toLowerCase();
}

const assets = {};
for (const spec of specs) {
  const separator = spec.indexOf("|");
  const kind = spec.slice(0, separator);
  const fileName = spec.slice(separator + 1);
  const filePath = path.join(stageDir, fileName);
  if (!checksums[fileName]) throw new Error(`Missing checksum for ${fileName}`);
  assets[kind] = {
    name: fileName,
    url: publicUrl(fileName),
    size: fs.statSync(filePath).size,
    sha256: checksums[fileName],
    signatureUrl: publicUrl(`${fileName}.asc`)
  };
}

const releaseNotes = [
  "Complete CGV Desktop installers with the private local scientific runtime included.",
  "Native macOS builds for Apple Silicon and Intel, plus Linux AppImage and Debian/Ubuntu packages.",
  "Windows 10 and 11 users can install the Windows x64 setup."
];

const manifest = {
  schemaVersion: 1,
  channel: "stable",
  product: "CGV Desktop",
  version,
  publishedAt: new Date().toISOString(),
  source: {
    label: "Oracle Cloud Object Storage",
    manifestUrl: publicUrl("desktop-release.json")
  },
  releaseNotes,
  assets,
  verification: {
    checksumsUrl: publicUrl("SHA256SUMS.txt"),
    checksumsSignatureUrl: publicUrl("SHA256SUMS.txt.asc"),
    publicKeyUrl: publicUrl("CGV-GPG-public-key.asc")
  }
};

fs.writeFileSync(
  path.join(stageDir, "desktop-release.json"),
  JSON.stringify(manifest, null, 2) + "\n"
);
NODE

(
  cd "$TEMP_STAGE"
  shasum -a 256 -c SHA256SUMS.txt >/dev/null
  for spec in "${ASSET_SPECS[@]}"; do
    filename="${spec#*|}"
    gpg --verify "$filename.asc" "$filename" >/dev/null 2>&1
  done
  gpg --verify SHA256SUMS.txt.asc SHA256SUMS.txt >/dev/null 2>&1
)

case "$OUTPUT_DIR" in
  "$DESKTOP_DIR"/oracle-upload-"$VERSION") ;;
  *) die "Ruta de salida inesperada: $OUTPUT_DIR" ;;
esac
rm -rf "$OUTPUT_DIR"
mv "$TEMP_STAGE" "$OUTPUT_DIR"
trap - EXIT

say "Paquete listo para Oracle"
find "$OUTPUT_DIR" -maxdepth 1 -type f -exec basename {} \; | sort
printf '\nSUBE TODO el contenido de:\n  %s\n\n' "$OUTPUT_DIR"
printf 'Importante: sube desktop-release.json AL FINAL. Así la página nunca\n'
printf 'anunciará una versión antes de que sus instaladores estén disponibles.\n'
printf '\nNo subas logs/, latest-linux.yml ni los ZIP de macOS para esta página.\n'
