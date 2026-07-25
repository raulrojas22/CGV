#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCKER_BIN="${DOCKER_BIN:-docker}"

docker_cmd() {
  ${DOCKER_BIN} "$@"
}

load_env_default() {
  local key="$1"
  local fallback="$2"
  local env_file="${ROOT}/.env"
  local val=""
  if [[ -f "${env_file}" ]]; then
    val="$(grep -E "^${key}=" "${env_file}" | tail -1 | cut -d= -f2- || true)"
    val="${val%\"}"
    val="${val#\"}"
    val="${val%\'}"
    val="${val#\'}"
  fi
  if [[ -n "${val}" ]]; then
    printf '%s' "${val}"
  else
    printf '%s' "${fallback}"
  fi
}

echo "============================================"
echo "  CGV prewarm — ejecutar UNA sola vez"
echo "  Antes de desplegar ShinyProxy"
echo "============================================"
echo ""
echo "Root: ${ROOT}"
echo ""

IMAGE="${CGV_IMAGE:-$(load_env_default CGV_IMAGE cgv:1.0.0)}"

if ! docker_cmd image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "Imagen '${IMAGE}' no encontrada. Construyendola..."
  (cd "${ROOT}" && docker_cmd compose build)
fi

echo "Ejecutando prewarming dentro de contenedor temporal..."
echo "  (montando datos como rw para escribir indices en el host)"

if [[ ! -s "${ROOT}/annotations/registry.tsv" ]]; then
  echo "ERROR: no existe o esta vacio ${ROOT}/annotations/registry.tsv" >&2
  echo "El prewarm necesita los datos montados en el NAS antes de iniciar ShinyProxy." >&2
  exit 1
fi
mkdir -p "${ROOT}/data/alias_index"

echo "Registry preloaded: ${ROOT}/annotations/registry.tsv ($(wc -l < "${ROOT}/annotations/registry.tsv") lineas)"

docker_cmd run --rm \
  --name cgv-prewarm-tmp \
  -v "${ROOT}/annotations:/app/annotations" \
  -v "${ROOT}/genomes:/app/genomes" \
  -v "${ROOT}/go_annotations:/app/go_annotations" \
  -v "${ROOT}/data:/app/data" \
  -v "${ROOT}/cache:/app/cache" \
  "${IMAGE}" \
  bash -c "
    set -euo pipefail
    echo '[1/2] Construyendo indices SQLite de alias...'
    Rscript scripts/build_alias_index_sqlite.R --root=/app --all || echo '  warning: no fatal'
    echo '[2/2] Precomputando caches de anotaciones y genomas...'
    Rscript scripts/precompute_preloaded_cache.R --root=/app || echo '  warning: no fatal'
  "

echo ""
echo "Prewarm completado."
echo ""
echo "Los indices SQLite estan en:"
echo "  ${ROOT}/annotations/"
echo "  ${ROOT}/genomes/"
echo "  ${ROOT}/cache/"
echo ""
echo "Ahora despliega ShinyProxy:"
echo "  docker compose -f docker-compose.shinyproxy.yml up -d"
