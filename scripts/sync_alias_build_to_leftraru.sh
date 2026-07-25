#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="rrojase@leftraru.nlhpc.cl"
REMOTE_PORT="4603"
REMOTE_DIR="/home/rrojase/cgv"
WITH_NCBI=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  bash scripts/sync_alias_build_to_leftraru.sh [options]

Options:
  --remote HOST        SSH host. Default: rrojase@leftraru.nlhpc.cl
  --port PORT          SSH port. Default: 4603
  --remote-dir DIR     Remote project dir. Default: /home/rrojase/cgv
  --with-ncbi          Also copy complete data/ncbi_gene/*.gz files. Recommended if already downloaded locally.
  --dry-run            Show rsync actions without copying.
  -h, --help           Show this help.

After sync, run on Leftraru:
  cd /home/rrojase/cgv
  sbatch scripts/run_alias_build_leftraru.sbatch

When it finishes, copy results back:
  rsync -avP -e 'ssh -p 4603' rrojase@leftraru.nlhpc.cl:/home/rrojase/cgv/data/alias_index/ data/alias_index/
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote)
      REMOTE_HOST="${2:?Missing value for --remote}"
      shift 2
      ;;
    --remote=*)
      REMOTE_HOST="${1#*=}"
      shift
      ;;
    --port)
      REMOTE_PORT="${2:?Missing value for --port}"
      shift 2
      ;;
    --port=*)
      REMOTE_PORT="${1#*=}"
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
    --with-ncbi)
      WITH_NCBI=1
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
  "scripts/run_alias_build_leftraru.sbatch"
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
RSYNC_SSH="ssh -p $REMOTE_PORT"

echo "Local project:  $ROOT_DIR"
echo "Remote target:  ${REMOTE_HOST}:${REMOTE_DIR}"
echo "SSH port:       $REMOTE_PORT"
echo "Copy NCBI gz:   $([[ "$WITH_NCBI" -eq 1 ]] && echo yes || echo no)"
echo

echo "Creating remote directories..."
ssh -p "$REMOTE_PORT" "$REMOTE_HOST" "mkdir -p '$REMOTE_DIR'/R '$REMOTE_DIR'/scripts '$REMOTE_DIR'/annotations '$REMOTE_DIR'/data/alias_index '$REMOTE_DIR'/data/ncbi_gene '$REMOTE_DIR'/logs"

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
  scripts/run_alias_build_leftraru.sbatch \
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
      echo "Run without --with-ncbi and let Leftraru download it, or finish the local download first." >&2
      exit 1
    fi
    gzip -t "$f"
  done

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
ssh -p "$REMOTE_PORT" "$REMOTE_HOST" "chmod +x '$REMOTE_DIR/scripts/run_alias_build_prefilter.sh' '$REMOTE_DIR/scripts/build_alias_index_enriched.R'"

cat <<EOF

Sync complete.

Next, connect to Leftraru:
  ssh -p $REMOTE_PORT $REMOTE_HOST

Then run:
  cd $REMOTE_DIR
  sbatch scripts/run_alias_build_leftraru.sbatch

For an interactive fallback without SLURM, use tmux or screen, for example:
  cd $REMOTE_DIR
  tmux new -s cgv_alias
  CGV_ALIAS_BUILD_WORKERS=2 CGV_ALIAS_SKIP_DOWNLOAD=1 bash scripts/run_alias_build_prefilter.sh

When it finishes, from your local CGV folder run:
  rsync -avP -e 'ssh -p $REMOTE_PORT' $REMOTE_HOST:$REMOTE_DIR/data/alias_index/ data/alias_index/

EOF
