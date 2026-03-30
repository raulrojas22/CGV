#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/app}"
APP_HOST="${APP_HOST:-0.0.0.0}"
APP_PORT="${APP_PORT:-3838}"
APP_PREWARM_ON_START="${APP_PREWARM_ON_START:-0}"
APP_PREWARM_CLEAN="${APP_PREWARM_CLEAN:-0}"
APP_PREWARM_BLOCK_START="${APP_PREWARM_BLOCK_START:-0}"

cd "${APP_DIR}"
mkdir -p cache/work_sessions

for required_dir in annotations genomes go_annotations; do
  if [[ ! -d "${required_dir}" ]]; then
    echo "[cgv] warning: '${required_dir}' directory not found in ${APP_DIR}"
  fi
done

if [[ "${APP_PREWARM_ON_START}" == "1" ]]; then
  echo "[cgv] prewarm enabled (APP_PREWARM_ON_START=1)"
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
