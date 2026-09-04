#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TRIALS="3"
RUN_PERF="1"
RUN_ALIGNED="1"
DO_PREWARM="0"
COLD_CACHE="0"
OUT_DIR=""

usage() {
  cat <<EOF
Usage: bash scripts/run_benchmark_suite.sh [options]

Options:
  --trials N           Number of trials for each suite (default: 3)
  --perf-only          Run only general perf benchmark
  --aligned-only       Run only aligned benchmark
  --prewarm            Run prewarm before benchmarks
  --cold-cache         Clear annotation/GO cache files before prewarm/bench
  --out-dir PATH       Output directory for logs and summaries
  --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --trials)
      TRIALS="${2:-}"
      shift 2
      ;;
    --perf-only)
      RUN_PERF="1"
      RUN_ALIGNED="0"
      shift
      ;;
    --aligned-only)
      RUN_PERF="0"
      RUN_ALIGNED="1"
      shift
      ;;
    --prewarm)
      DO_PREWARM="1"
      shift
      ;;
    --cold-cache)
      COLD_CACHE="1"
      shift
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if ! [[ "$TRIALS" =~ ^[0-9]+$ ]] || [[ "$TRIALS" -lt 1 ]]; then
  echo "Invalid --trials value: $TRIALS"
  exit 1
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="/tmp/fullapp_benchmark_suite_$(date +%Y%m%d_%H%M%S)"
fi

mkdir -p "$OUT_DIR"
cd "$ROOT_DIR"

echo "Benchmark suite output: $OUT_DIR"
echo "Trials: $TRIALS"
echo "Run general perf suite: $RUN_PERF"
echo "Run aligned suite: $RUN_ALIGNED"
echo "Prewarm first: $DO_PREWARM"
echo "Cold cache first: $COLD_CACHE"
echo

if [[ "$COLD_CACHE" == "1" ]]; then
  echo "[suite] Clearing selected cache artifacts..."
  rm -f "$ROOT_DIR"/cache/annotation_index/*.rds || true
  rm -f "$ROOT_DIR"/cache/go_term_map.rds || true
  rm -f "$ROOT_DIR"/go_annotations/go_term_map.rds || true
  echo "[suite] Cache clear done."
  echo
fi

if [[ "$DO_PREWARM" == "1" ]]; then
  echo "[suite] Running prewarm..."
  if [[ "$COLD_CACHE" == "1" ]]; then
    Rscript "$ROOT_DIR/scripts/precompute_preloaded_cache.R" --root="$ROOT_DIR" --clean | tee "$OUT_DIR/prewarm.log"
  else
    Rscript "$ROOT_DIR/scripts/precompute_preloaded_cache.R" --root="$ROOT_DIR" | tee "$OUT_DIR/prewarm.log"
  fi
  echo "[suite] Prewarm finished."
  echo
fi

cp "$ROOT_DIR/scripts/PERF_QUICKSTART.md" "$OUT_DIR/PERF_QUICKSTART.md"
cp "$ROOT_DIR/scripts/BENCHMARK_PROTOCOL.md" "$OUT_DIR/BENCHMARK_PROTOCOL.md"

if [[ "$RUN_PERF" == "1" ]]; then
  echo "[suite] Running general perf benchmark..."
  bash "$ROOT_DIR/scripts/run_perf_benchmark_3x.sh" "$TRIALS" | tee "$OUT_DIR/perf_suite.log"
  echo "[suite] General perf benchmark finished."
  echo
fi

if [[ "$RUN_ALIGNED" == "1" ]]; then
  echo "[suite] Running aligned benchmark..."
  bash "$ROOT_DIR/scripts/run_aligned_benchmark_3x.sh" "$TRIALS" | tee "$OUT_DIR/aligned_suite.log"
  echo "[suite] Aligned benchmark finished."
  echo
fi

echo "Suite complete."
echo "Output directory: $OUT_DIR"
echo "Use these guides during each interactive run:"
echo "  $OUT_DIR/PERF_QUICKSTART.md"
echo "  $OUT_DIR/BENCHMARK_PROTOCOL.md"
