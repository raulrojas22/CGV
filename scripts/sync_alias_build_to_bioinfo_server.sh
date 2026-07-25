#!/usr/bin/env bash
set -euo pipefail

JUMP_HOST="rarojas@bioinfo.utalca.cl"
JUMP_PORT="2222"
REMOTE_HOST="rarojas@10.1.1.64"
REMOTE_DIR="/home/rarojas/cgv"
WITH_NCBI=1
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  bash scripts/sync_alias_build_to_bioinfo_server.sh [options]

Defaults:
  Jump host:       rarojas@bioinfo.utalca.cl
  Jump port:       2222
  Destination:     rarojas@10.1.1.64:/home/rarojas/cgv
  Copy NCBI gz:    yes

Options:
  --jump HOST          ProxyJump host. Default: rarojas@bioinfo.utalca.cl
  --jump-port PORT     ProxyJump SSH port. Default: 2222
  --remote HOST        Final server host. Default: rarojas@10.1.1.64
  --remote-dir DIR     Remote project dir. Default: /home/rarojas/cgv
  --without-ncbi       Do not copy data/ncbi_gene/*.gz.
  --dry-run            Show rsync actions without copying.
  -h, --help           Show this help.

After sync, connect with:
  ssh -p 2222 rarojas@bioinfo.utalca.cl
  ssh rarojas@10.1.1.64

Then run on the final server:
  cd /home/rarojas/cgv
  nohup nice -n 5 env CGV_ALIAS_BUILD_WORKERS=24 CGV_ALIAS_SKIP_DOWNLOAD=1 \
    bash scripts/run_alias_build_prefilter.sh \
    > logs/nohup_alias_build.log 2>&1 &

Watch progress:
  tail -f /home/rarojas/cgv/logs/nohup_alias_build.log

Copy results back to this Mac:
  rsync -avP -e 'ssh -J rarojas@bioinfo.utalca.cl:2222' \
    rarojas@10.1.1.64:/home/rarojas/cgv/data/alias_index/ data/alias_index/
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jump)
      JUMP_HOST="${2:?Missing value for --jump}"
      shift 2
      ;;
    --jump=*)
      JUMP_HOST="${1#*=}"
      shift
      ;;
    --jump-port)
      JUMP_PORT="${2:?Missing value for --jump-port}"
      shift 2
      ;;
    --jump-port=*)
      JUMP_PORT="${1#*=}"
      shift
      ;;
    --remote)
      REMOTE_HOST="${2:?Missing value for --remote}"
      shift 2
      ;;
    --remote=*)
      REMOTE_HOST="${1#*=}"
      shift
      ;;
    --remote-dir)
      REMOTE_DIR="${2:?Missing value for --remote-dir}"
      shift 2
      ;;
    --remote-dir=*)
      REMOTE_DIR="${1#*=}"
      shift
      ;;
    --without-ncbi)
      WITH_NCBI=0
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

required_paths=(
  "R/alias_resolution.R"
  "R/utils.R"
  "scripts/build_alias_index_enriched.R"
  "scripts/build_alias_index_biomart.R"
  "scripts/enrich_alias_index_biomart_append.R"
  "scripts/run_alias_build_prefilter.sh"
  "scripts/test_alias_index_resolution.R"
  "annotations/registry.tsv"
)

for path in "${required_paths[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "ERROR: required path missing: $path" >&2
    exit 1
  fi
done

if [[ ! -d annotations ]]; then
  echo "ERROR: annotations/ directory is missing." >&2
  exit 1
fi

RSYNC_FLAGS=(-avP)
if [[ "$DRY_RUN" -eq 1 ]]; then
  RSYNC_FLAGS+=(--dry-run)
fi
RSYNC_SSH="ssh -J ${JUMP_HOST}:${JUMP_PORT}"

echo "Local project:  $ROOT_DIR"
echo "Jump host:      ${JUMP_HOST}:${JUMP_PORT}"
echo "Remote target:  ${REMOTE_HOST}:${REMOTE_DIR}"
echo "Copy NCBI gz:   $([[ "$WITH_NCBI" -eq 1 ]] && echo yes || echo no)"
echo

if [[ "$WITH_NCBI" -eq 1 ]]; then
  echo "Checking local NCBI gz integrity before copying..."
  ncbi_files=(
    "data/ncbi_gene/gene_info.gz"
    "data/ncbi_gene/gene2refseq.gz"
    "data/ncbi_gene/gene2accession.gz"
    "data/ncbi_gene/gene2ensembl.gz"
  )
  for f in "${ncbi_files[@]}"; do
    if [[ ! -f "$f" ]]; then
      echo "ERROR: missing NCBI file: $f" >&2
      exit 1
    fi
    gzip -t "$f"
  done
fi

echo
echo "Creating remote directories..."
ssh -J "${JUMP_HOST}:${JUMP_PORT}" "$REMOTE_HOST" \
  "mkdir -p '$REMOTE_DIR'/R '$REMOTE_DIR'/scripts '$REMOTE_DIR'/annotations '$REMOTE_DIR'/data/alias_index '$REMOTE_DIR'/data/ncbi_gene '$REMOTE_DIR'/logs"

echo
echo "Syncing R helpers and build scripts..."
rsync "${RSYNC_FLAGS[@]}" \
  -e "$RSYNC_SSH" \
  R/alias_resolution.R \
  R/utils.R \
  "$REMOTE_HOST:$REMOTE_DIR/R/"

rsync "${RSYNC_FLAGS[@]}" \
  -e "$RSYNC_SSH" \
  scripts/build_alias_index_enriched.R \
  scripts/build_alias_index_biomart.R \
  scripts/enrich_alias_index_biomart_append.R \
  scripts/run_alias_build_prefilter.sh \
  scripts/test_alias_index_resolution.R \
  "$REMOTE_HOST:$REMOTE_DIR/scripts/"

echo
echo "Syncing annotations/..."
rsync "${RSYNC_FLAGS[@]}" \
  -e "$RSYNC_SSH" \
  --exclude ".DS_Store" \
  annotations/ \
  "$REMOTE_HOST:$REMOTE_DIR/annotations/"

if [[ "$WITH_NCBI" -eq 1 ]]; then
  echo
  echo "Syncing complete NCBI gz files..."
  rsync "${RSYNC_FLAGS[@]}" \
    -e "$RSYNC_SSH" \
    data/ncbi_gene/gene_info.gz \
    data/ncbi_gene/gene2refseq.gz \
    data/ncbi_gene/gene2accession.gz \
    data/ncbi_gene/gene2ensembl.gz \
    "$REMOTE_HOST:$REMOTE_DIR/data/ncbi_gene/"
fi

echo
echo "Making remote runner executable..."
ssh -J "${JUMP_HOST}:${JUMP_PORT}" "$REMOTE_HOST" \
  "chmod +x '$REMOTE_DIR/scripts/run_alias_build_prefilter.sh' '$REMOTE_DIR/scripts/build_alias_index_enriched.R'"

cat <<EOF

Sync complete.

Connect:
  ssh -p $JUMP_PORT $JUMP_HOST
  ssh $REMOTE_HOST

Check R packages:
  cd $REMOTE_DIR
  Rscript -e 'stopifnot(requireNamespace("dplyr", quietly=TRUE), requireNamespace("jsonlite", quietly=TRUE)); cat("R packages ok\n")'

Run:
  cd $REMOTE_DIR
  nohup nice -n 5 env CGV_ALIAS_BUILD_WORKERS=24 CGV_ALIAS_SKIP_DOWNLOAD=1 \\
    bash scripts/run_alias_build_prefilter.sh \\
    > logs/nohup_alias_build.log 2>&1 &

Watch:
  tail -f $REMOTE_DIR/logs/nohup_alias_build.log

Copy results back:
  rsync -avP -e 'ssh -J $JUMP_HOST:$JUMP_PORT' \\
    $REMOTE_HOST:$REMOTE_DIR/data/alias_index/ data/alias_index/

EOF
