#!/usr/bin/env bash
#
# Registra una sola vez la URL pública estable desde la que CGV Web y
# CGV Desktop leerán desktop-release.json.
#
# Uso:
#   ./scripts/configurar-url-oracle-desktop.sh \
#     "https://objectstorage.<region>.oraclecloud.com/.../o/cgv-desktop"
#
# También acepta la URL completa terminada en /desktop-release.json.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/www/desktop-release-source.json"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

if [ "${1:-}" = "--show" ]; then
  node -e '
    const config = require(process.argv[1]);
    console.log(config.manifestUrl || "(URL de Oracle todavía no configurada)");
  ' "$CONFIG_FILE"
  exit 0
fi

[ "$#" -eq 1 ] || die "Uso: $0 <URL-base-publica-o-URL-del-manifiesto>"

INPUT_URL="${1%/}"
case "$INPUT_URL" in
  https://*) ;;
  *) die "La URL pública debe comenzar con https://";;
esac

case "$INPUT_URL" in
  */desktop-release.json) MANIFEST_URL="$INPUT_URL" ;;
  *) MANIFEST_URL="$INPUT_URL/desktop-release.json" ;;
esac

node -e '
  const parsed = new URL(process.argv[1]);
  if (parsed.protocol !== "https:") throw new Error("Only HTTPS release URLs are accepted.");
  if (parsed.search || parsed.hash) throw new Error("The release URL cannot contain a query string or fragment.");
' "$MANIFEST_URL"

TEMP_FILE="$(mktemp "${TMPDIR:-/tmp}/cgv-desktop-release-source.XXXXXX")"
trap 'rm -f "$TEMP_FILE"' EXIT

node - "$CONFIG_FILE" "$MANIFEST_URL" "$TEMP_FILE" <<'NODE'
const fs = require("fs");

const configPath = process.argv[2];
const manifestUrl = process.argv[3];
const outputPath = process.argv[4];
const current = JSON.parse(fs.readFileSync(configPath, "utf8"));

current.manifestUrl = manifestUrl;
fs.writeFileSync(outputPath, JSON.stringify(current, null, 2) + "\n");
NODE

mv "$TEMP_FILE" "$CONFIG_FILE"
trap - EXIT

printf '\nURL de publicación configurada:\n  %s\n\n' "$MANIFEST_URL"
printf 'Despliega este cambio en CGV Web e inclúyelo en el próximo build de\n'
printf 'Desktop. Conserva la misma URL base para las versiones futuras.\n\n'
printf 'Siguiente paso:\n  ./scripts/preparar-publicacion-desktop.sh\n'
