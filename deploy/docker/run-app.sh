#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/app}"
APP_HOST="${APP_HOST:-0.0.0.0}"
APP_PORT="${APP_PORT:-3838}"
APP_PREWARM_ON_START="${APP_PREWARM_ON_START:-0}"
APP_PREWARM_CLEAN="${APP_PREWARM_CLEAN:-0}"
APP_PREWARM_BLOCK_START="${APP_PREWARM_BLOCK_START:-0}"
CGV_DATA_ROOT="${CGV_DATA_ROOT:-${APP_DIR}}"
CGV_CACHE_DIR="${CGV_CACHE_DIR:-${APP_DIR}/cache}"
APP_ALIAS_DISK_CACHE_DIR="${APP_ALIAS_DISK_CACHE_DIR:-${CGV_CACHE_DIR}/external_alias}"
GDTOOLS_CACHE_DIR="${GDTOOLS_CACHE_DIR:-${CGV_CACHE_DIR}/gdtools}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-${CGV_CACHE_DIR}/xdg-cache}"
XDG_DATA_HOME="${XDG_DATA_HOME:-${CGV_CACHE_DIR}/xdg-data}"
APP_START_EPOCH="${APP_START_EPOCH:-$(date +%s)}"

export \
  CGV_DATA_ROOT \
  CGV_CACHE_DIR \
  APP_ALIAS_DISK_CACHE_DIR \
  GDTOOLS_CACHE_DIR \
  XDG_CACHE_HOME \
  XDG_DATA_HOME \
  APP_START_EPOCH

cd "${APP_DIR}"
mkdir -p cache/work_sessions
mkdir -p \
  "${CGV_CACHE_DIR}/work_sessions" \
  "${CGV_CACHE_DIR}/external_alias" \
  "${CGV_CACHE_DIR}/annotation_index" \
  "${CGV_CACHE_DIR}/go_index" \
  "${CGV_CACHE_DIR}/string/resolved" \
  "${CGV_CACHE_DIR}/string/network" \
  "${GDTOOLS_CACHE_DIR}" \
  "${XDG_CACHE_HOME}" \
  "${XDG_DATA_HOME}"

if [[ "${APP_SESSION_METRICS:-0}" == "1" ]]; then
  echo "[cgv] startup app_dir=${APP_DIR} data_root=${CGV_DATA_ROOT} cache_dir=${CGV_CACHE_DIR} pid=$$"
fi

for required_dir in annotations genomes go_annotations data/alias_index; do
  if [[ ! -d "${CGV_DATA_ROOT}/${required_dir}" ]]; then
    echo "[cgv] warning: '${required_dir}' directory not found in ${CGV_DATA_ROOT}"
  fi
done

if [[ "${APP_PREWARM_ON_START}" == "1" ]]; then
  echo "[cgv] prewarm enabled (APP_PREWARM_ON_START=1)"

  echo "[cgv] building alias index SQLite databases..."
  if Rscript scripts/build_alias_index_sqlite.R "--root=${APP_DIR}" --all; then
    echo "[cgv] alias sqlite build completed"
  else
    echo "[cgv] warning: alias sqlite build had errors (non-fatal)"
  fi

  prewarm_args=(scripts/precompute_preloaded_cache.R "--root=${APP_DIR}")
  if [[ "${APP_PREWARM_CLEAN}" == "1" ]]; then
    prewarm_args+=("--clean")
  fi

  if Rscript "${prewarm_args[@]}"; then
    echo "[cgv] prewarm completed"
  else
    echo "[cgv] warning: prewarm failed"
    if [[ "${APP_PREWARM_BLOCK_START}" == "1" ]]; then
      echo "[cgv] APP_PREWARM_BLOCK_START=1, aborting startup"
      exit 1
    fi
  fi
fi

echo "[cgv] starting Shiny app at ${APP_HOST}:${APP_PORT}"
exec Rscript -e "shiny::runApp('${APP_DIR}', host='${APP_HOST}', port=as.integer('${APP_PORT}'), launch.browser=FALSE)"
