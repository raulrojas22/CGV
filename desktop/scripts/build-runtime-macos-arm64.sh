#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${DESKTOP_DIR}/resources/r/darwin-arm64"
ENV_NAME="${CGV_RUNTIME_ENV_NAME:-cgv-desktop-darwin-arm64}"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "ERROR: this script builds the macOS arm64 runtime and must run on Apple Silicon macOS." >&2
  exit 1
fi

CONDA_EXE="${CGV_CONDA_EXE:-}"
if [[ -z "${CONDA_EXE}" ]]; then
  if command -v micromamba >/dev/null 2>&1; then
    CONDA_EXE="micromamba"
  elif command -v mamba >/dev/null 2>&1; then
    CONDA_EXE="mamba"
  elif command -v conda >/dev/null 2>&1; then
    CONDA_EXE="conda"
  fi
fi

if [[ -z "${CONDA_EXE}" ]]; then
  echo "ERROR: micromamba, mamba, or conda is required." >&2
  exit 1
fi

if command -v conda-pack >/dev/null 2>&1; then
  CONDA_PACK=(conda-pack)
elif python -m conda_pack --help >/dev/null 2>&1; then
  CONDA_PACK=(python -m conda_pack)
else
  echo "ERROR: conda-pack is required. Install it with: ${CONDA_EXE} install -n base -c conda-forge conda-pack" >&2
  exit 1
fi

if ! "${CONDA_EXE}" env list | awk '{print $1}' | grep -Fxq "${ENV_NAME}"; then
  "${CONDA_EXE}" create -y -n "${ENV_NAME}" -c conda-forge -c bioconda \
    r-base=4.4 \
    r-shiny r-bslib r-shinyjs r-shinycssloaders r-shinywidgets \
    r-dplyr r-tidyr r-purrr r-stringr r-ggiraph r-ggplot2 r-ggrepel \
    r-patchwork r-scales r-vroom r-future r-promises r-httr2 r-furrr \
    r-visnetwork r-jsonlite r-later r-htmltools r-dt r-sass \
    r-data.table r-processx r-dbi r-rsqlite \
    bioconductor-biostrings bioconductor-rsamtools bioconductor-genomicranges \
    bioconductor-iranges bioconductor-genomeinfodb bioconductor-rtracklayer \
    bioconductor-biomart bioconductor-pwalign \
    lastz samtools htslib
fi

"${CONDA_EXE}" run -n "${ENV_NAME}" env R_LIBS_USER= R_LIBS_SITE= Rscript \
  -e ".libPaths(.Library); source('${DESKTOP_DIR}/../deploy/docker/install_packages.R')"

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"
"${CONDA_PACK[@]}" -n "${ENV_NAME}" -o "${OUT_DIR}.tar.gz" --force
tar -xzf "${OUT_DIR}.tar.gz" -C "${OUT_DIR}"
rm -f "${OUT_DIR}.tar.gz"
node "${DESKTOP_DIR}/scripts/prune-runtime.js" darwin-arm64

echo "Runtime written to ${OUT_DIR}"
