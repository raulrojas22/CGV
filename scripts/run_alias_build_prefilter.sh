#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

WORKERS="${CGV_ALIAS_BUILD_WORKERS:-2}"
SKIP_DOWNLOAD="${CGV_ALIAS_SKIP_DOWNLOAD:-0}"
REFRESH_PREFILTER="${CGV_ALIAS_REFRESH_PREFILTER:-0}"

if ! command -v Rscript >/dev/null 2>&1; then
  echo "ERROR: Rscript is not available in PATH." >&2
  exit 1
fi

mkdir -p data/alias_index data/ncbi_gene logs

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="logs/alias_build_prefilter_${STAMP}.log"

echo "Running CGV alias index build in: $PWD"
echo "Workers: $WORKERS"
echo "Skip download: $SKIP_DOWNLOAD"
echo "Refresh prefilter: $REFRESH_PREFILTER"
echo "Log: $LOG_FILE"
echo

EXTRA_ARGS=()
if [[ "$SKIP_DOWNLOAD" == "1" || "$SKIP_DOWNLOAD" == "true" || "$SKIP_DOWNLOAD" == "TRUE" ]]; then
  EXTRA_ARGS+=(--skip-download)
fi
if [[ "$REFRESH_PREFILTER" == "1" || "$REFRESH_PREFILTER" == "true" || "$REFRESH_PREFILTER" == "TRUE" ]]; then
  EXTRA_ARGS+=(--refresh-prefilter)
fi

Rscript scripts/build_alias_index_enriched.R \
  --all \
  --prefilter-ncbi \
  --workers="$WORKERS" \
  --download-timeout-sec=14400 \
  "${EXTRA_ARGS[@]}" 2>&1 | tee "$LOG_FILE"

echo
echo "Done. Alias indexes are in: $PWD/data/alias_index"
