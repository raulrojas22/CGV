#!/usr/bin/env bash
set -euo pipefail

STATIC_SOURCE_DIR="${CGV_STATIC_SOURCE_DIR:-/app/www}"
STATIC_ROOT="${CGV_STATIC_ROOT_DIR:-/app/cache/static_assets}"
REVISION="${CGV_STATIC_REVISION:-}"

if [[ ! "${REVISION}" =~ ^[a-f0-9]{64}$ ]]; then
  echo "ERROR: CGV_STATIC_REVISION debe ser un Id sha256 de 64 caracteres." >&2
  exit 1
fi
if [[ ! -d "${STATIC_SOURCE_DIR}" ]]; then
  echo "ERROR: no existe el directorio estático de la imagen: ${STATIC_SOURCE_DIR}" >&2
  exit 1
fi

RELEASES_DIR="${STATIC_ROOT}/releases"
MANIFESTS_DIR="${STATIC_ROOT}/manifests"
STAGING_DIR="${STATIC_ROOT}/staging"
LOCKS_DIR="${STATIC_ROOT}/locks"
DESTINATION="${RELEASES_DIR}/${REVISION}"
PUBLISHED_MANIFEST="${MANIFESTS_DIR}/${REVISION}.sha256"
SOURCE_MANIFEST=""
STAGED_SNAPSHOT=""
STAGED_MANIFEST=""
MANIFEST_CANDIDATE=""
LOCK_DIR="${LOCKS_DIR}/${REVISION}.lock"
LOCK_ACQUIRED=0

static_manifest() {
  local snapshot_dir="$1"
  local manifest_path="$2"
  (
    cd "${snapshot_dir}"
    find . -type f -print | LC_ALL=C sort | while IFS= read -r asset_path; do
      if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "${asset_path}"
      else
        shasum -a 256 "${asset_path}"
      fi
    done
  ) > "${manifest_path}"
}

cleanup_static_staging() {
  if [[ -n "${SOURCE_MANIFEST}" ]]; then rm -f -- "${SOURCE_MANIFEST}"; fi
  if [[ -n "${STAGED_MANIFEST}" ]]; then rm -f -- "${STAGED_MANIFEST}"; fi
  if [[ -n "${MANIFEST_CANDIDATE}" ]]; then rm -f -- "${MANIFEST_CANDIDATE}"; fi
  if [[ -n "${STAGED_SNAPSHOT}" && -d "${STAGED_SNAPSHOT}" ]]; then
    rm -rf -- "${STAGED_SNAPSHOT}"
  fi
  if [[ "${LOCK_ACQUIRED}" == "1" ]]; then
    rmdir "${LOCK_DIR}" 2>/dev/null || true
  fi
}
trap cleanup_static_staging EXIT INT TERM

mkdir -p "${RELEASES_DIR}" "${MANIFESTS_DIR}" "${STAGING_DIR}" "${LOCKS_DIR}"
chmod 0755 "${STATIC_ROOT}" "${RELEASES_DIR}" "${MANIFESTS_DIR}"
chmod 0700 "${STAGING_DIR}" "${LOCKS_DIR}"
if ! mkdir "${LOCK_DIR}"; then
  echo "ERROR: ya existe una publicación en curso para ${REVISION}." >&2
  exit 1
fi
LOCK_ACQUIRED=1

if find "${STATIC_SOURCE_DIR}" -type l -print -quit | grep -q .; then
  echo "ERROR: ${STATIC_SOURCE_DIR} contiene enlaces simbólicos; no se publicará." >&2
  exit 1
fi

SOURCE_MANIFEST="$(mktemp "${STATIC_ROOT}/.source-${REVISION}.XXXXXX")"
static_manifest "${STATIC_SOURCE_DIR}" "${SOURCE_MANIFEST}"
if [[ ! -s "${SOURCE_MANIFEST}" ]]; then
  echo "ERROR: ${STATIC_SOURCE_DIR} no contiene archivos publicables." >&2
  exit 1
fi

if [[ -e "${DESTINATION}" ]]; then
  if [[ ! -d "${DESTINATION}" ]]; then
    echo "ERROR: el destino existe pero no es un directorio: ${DESTINATION}" >&2
    exit 1
  fi
  STAGED_MANIFEST="$(mktemp "${STATIC_ROOT}/.verify-${REVISION}.XXXXXX")"
  static_manifest "${DESTINATION}" "${STAGED_MANIFEST}"
  if ! cmp -s "${SOURCE_MANIFEST}" "${STAGED_MANIFEST}"; then
    echo "ERROR: el snapshot existente difiere y no será reemplazado: ${DESTINATION}" >&2
    exit 1
  fi
  if [[ ! -f "${PUBLISHED_MANIFEST}" ]] || \
     ! cmp -s "${SOURCE_MANIFEST}" "${PUBLISHED_MANIFEST}"; then
    MANIFEST_CANDIDATE="$(mktemp "${MANIFESTS_DIR}/.${REVISION}.XXXXXX")"
    cp "${SOURCE_MANIFEST}" "${MANIFEST_CANDIDATE}"
    chmod 0444 "${MANIFEST_CANDIDATE}"
    mv -f "${MANIFEST_CANDIDATE}" "${PUBLISHED_MANIFEST}"
  fi
  find "${DESTINATION}" -type d -exec chmod 0555 {} +
  find "${DESTINATION}" -type f -exec chmod 0444 {} +
  echo "[1/3] Snapshot estático ya publicado y verificado: ${REVISION}"
  exit 0
fi

STAGED_SNAPSHOT="$(mktemp -d "${STAGING_DIR}/${REVISION}.XXXXXX")"
cp -a "${STATIC_SOURCE_DIR}/." "${STAGED_SNAPSHOT}/"
if find "${STAGED_SNAPSHOT}" -type l -print -quit | grep -q .; then
  echo "ERROR: el snapshot copiado contiene enlaces simbólicos." >&2
  exit 1
fi
STAGED_MANIFEST="$(mktemp "${STATIC_ROOT}/.staged-${REVISION}.XXXXXX")"
static_manifest "${STAGED_SNAPSHOT}" "${STAGED_MANIFEST}"
if ! cmp -s "${SOURCE_MANIFEST}" "${STAGED_MANIFEST}"; then
  echo "ERROR: la copia estática no coincide byte a byte con la imagen." >&2
  exit 1
fi

if mv "${STAGED_SNAPSHOT}" "${DESTINATION}"; then
  STAGED_SNAPSHOT=""
else
  echo "ERROR: no se pudo publicar atómicamente ${DESTINATION}." >&2
  exit 1
fi
find "${DESTINATION}" -type d -exec chmod 0555 {} +
find "${DESTINATION}" -type f -exec chmod 0444 {} +

MANIFEST_CANDIDATE="$(mktemp "${MANIFESTS_DIR}/.${REVISION}.XXXXXX")"
cp "${SOURCE_MANIFEST}" "${MANIFEST_CANDIDATE}"
chmod 0444 "${MANIFEST_CANDIDATE}"
mv -f "${MANIFEST_CANDIDATE}" "${PUBLISHED_MANIFEST}"
echo "[1/3] Snapshot estático publicado: ${REVISION}"
