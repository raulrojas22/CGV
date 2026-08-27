#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCKER_BIN="${DOCKER_BIN:-docker}"

resolve_host_dir() {
  local path="$1"
  if [[ "${path}" = /* ]]; then
    printf '%s' "${path}"
  else
    printf '%s/%s' "${ROOT}" "${path#./}"
  fi
}

docker_cmd() {
  ${DOCKER_BIN} "$@"
}

load_env_default() {
  local key="$1"
  local fallback="$2"
  local val=""
  local env_file
  for env_file in "${ROOT}/.env" "${ROOT}/.env.local"; do
    if [[ -f "${env_file}" ]]; then
      local candidate
      candidate="$(grep -E "^${key}=" "${env_file}" | tail -1 | cut -d= -f2- || true)"
      if [[ -n "${candidate}" ]]; then
        val="${candidate}"
      fi
    fi
  done
  val="${val%\"}"
  val="${val#\"}"
  val="${val%\'}"
  val="${val#\'}"
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
ANNOTATIONS_DIR="$(resolve_host_dir "${CGV_ANNOTATIONS_DIR:-$(load_env_default CGV_ANNOTATIONS_DIR annotations)}")"
GENOMES_DIR="$(resolve_host_dir "${CGV_GENOMES_DIR:-$(load_env_default CGV_GENOMES_DIR genomes)}")"
GO_ANNOTATIONS_DIR="$(resolve_host_dir "${CGV_GO_ANNOTATIONS_DIR:-$(load_env_default CGV_GO_ANNOTATIONS_DIR go_annotations)}")"
DATA_DIR="$(resolve_host_dir "${CGV_DATA_DIR:-$(load_env_default CGV_DATA_DIR data)}")"
CACHE_DIR="$(resolve_host_dir "${CGV_CACHE_DIR:-$(load_env_default CGV_CACHE_DIR cache)}")"
PUBLISH_STATIC_ASSETS="${CGV_PUBLISH_STATIC_ASSETS:-0}"

if [[ "${PUBLISH_STATIC_ASSETS}" != "0" && "${PUBLISH_STATIC_ASSETS}" != "1" ]]; then
  echo "ERROR: CGV_PUBLISH_STATIC_ASSETS debe ser 0 o 1." >&2
  exit 1
fi

if ! docker_cmd image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "ERROR: imagen de prewarm '${IMAGE}' no encontrada." >&2
  echo "Construye la imagen que desplegaras antes de ejecutar este helper." >&2
  exit 1
fi

STATIC_REVISION=""
if [[ "${PUBLISH_STATIC_ASSETS}" == "1" ]]; then
  IMAGE_ID="$(docker_cmd image inspect --format '{{.Id}}' "${IMAGE}" | tr -d '\r\n')"
  IMAGE_REVISION="${IMAGE_ID#sha256:}"
  STATIC_REVISION="${CGV_STATIC_REVISION:-${IMAGE_REVISION}}"
  STATIC_REVISION="${STATIC_REVISION#sha256:}"
  if [[ ! "${IMAGE_REVISION}" =~ ^[a-f0-9]{64}$ ]]; then
    echo "ERROR: la imagen '${IMAGE}' no devolvió un Id sha256 válido: ${IMAGE_ID}" >&2
    exit 1
  fi
  if [[ ! "${STATIC_REVISION}" =~ ^[a-f0-9]{64}$ ]]; then
    echo "ERROR: CGV_STATIC_REVISION debe contener exactamente 64 caracteres hexadecimales." >&2
    exit 1
  fi
  if [[ "${STATIC_REVISION}" != "${IMAGE_REVISION}" ]]; then
    echo "ERROR: CGV_STATIC_REVISION no coincide con la imagen exacta de prewarm." >&2
    echo "  esperado: ${IMAGE_REVISION}" >&2
    echo "  recibido: ${STATIC_REVISION}" >&2
    exit 1
  fi
fi

echo "Ejecutando prewarming dentro de contenedor temporal..."
echo "  (montando datos como rw para escribir indices en el host)"

if [[ ! -s "${ANNOTATIONS_DIR}/registry.tsv" ]]; then
  echo "ERROR: no existe o esta vacio ${ANNOTATIONS_DIR}/registry.tsv" >&2
  echo "El prewarm necesita los datos montados en el NAS antes de iniciar ShinyProxy." >&2
  exit 1
fi
mkdir -p "${DATA_DIR}/alias_index" "${CACHE_DIR}"

echo "Registry preloaded: ${ANNOTATIONS_DIR}/registry.tsv ($(wc -l < "${ANNOTATIONS_DIR}/registry.tsv") lineas)"
echo "Imagen prewarm: ${IMAGE}"
if [[ "${PUBLISH_STATIC_ASSETS}" == "1" ]]; then
  echo "Snapshot estático: ${STATIC_REVISION}"
fi
echo "Datos prewarm: annotations=${ANNOTATIONS_DIR} data=${DATA_DIR} cache=${CACHE_DIR}"

docker_cmd run --rm \
  --name cgv-prewarm-tmp \
  -e "CGV_PUBLISH_STATIC_ASSETS=${PUBLISH_STATIC_ASSETS}" \
  -e "CGV_STATIC_REVISION=${STATIC_REVISION}" \
  -v "${ANNOTATIONS_DIR}:/app/annotations" \
  -v "${GENOMES_DIR}:/app/genomes" \
  -v "${GO_ANNOTATIONS_DIR}:/app/go_annotations" \
  -v "${DATA_DIR}:/app/data" \
  -v "${CACHE_DIR}:/app/cache" \
  "${IMAGE}" \
  bash -c '
    set -euo pipefail

    if [ "$CGV_PUBLISH_STATIC_ASSETS" = 1 ]; then
      bash docker/publish-static-assets.sh
      echo "[2/3] Construyendo indices SQLite de alias..."
    else
      echo "[1/2] Construyendo indices SQLite de alias..."
    fi
    Rscript scripts/build_alias_index_sqlite.R --root=/app --all
    if [ "$CGV_PUBLISH_STATIC_ASSETS" = 1 ]; then
      echo "[3/3] Precomputando caches de anotaciones y genomas..."
    else
      echo "[2/2] Precomputando caches de anotaciones y genomas..."
    fi
    Rscript scripts/precompute_preloaded_cache.R --root=/app || echo "  warning: no fatal"
    Rscript scripts/verify_preloaded_alias_indexes.R --root=/app
  '

echo ""
echo "Prewarm completado."
echo ""
echo "Los indices SQLite estan en:"
echo "  ${DATA_DIR}/alias_index/"
echo "  ${ANNOTATIONS_DIR}/"
echo "  ${GENOMES_DIR}/"
echo "  ${CACHE_DIR}/"
echo ""
echo "Ahora despliega ShinyProxy:"
echo "  docker compose -f docker-compose.shinyproxy.yml up -d"
