#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TRIALS="${1:-3}"
BENCH_DIR="/tmp/fullapp_perf_benchmark_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BENCH_DIR"
cd "$ROOT_DIR"

if ! [[ "$TRIALS" =~ ^[0-9]+$ ]] || [[ "$TRIALS" -lt 1 ]]; then
  echo "Invalid number of trials: $TRIALS"
  echo "Usage: $0 [num_trials]"
  exit 1
fi

echo "Benchmark dir: $BENCH_DIR"
echo "This will run $TRIALS trial(s) (ON then OFF)."
echo "Eager render defaults are fixed for this benchmark:"
echo "  APP_HOMO_INITIAL_VISIBLE=64 APP_ORTHO_INITIAL_VISIBLE=64 APP_ORTHO_RENDER_CHUNK_SIZE=64"
echo "  APP_ORTHO_AUTO_RENDER_MORE=0 APP_ORTHO_SERVER_RENDER_NUDGE=0 DEFER_SEQUENCE/GC=0"
echo "Aligned fast-path defaults are fixed for this benchmark:"
echo "  APP_ORTHO_ALIGNED_FAST=1"
echo "Future defaults for this benchmark:"
echo "  APP_FUTURE_MODE=${APP_FUTURE_MODE:-multisession} APP_FUTURE_WORKERS=${APP_FUTURE_WORKERS:-2}"
echo "For each run: perform the same UI flow, then press Ctrl+C in this terminal."
echo

run_one() {
  local mode="$1"
  local trial="$2"
  local logfile="$3"
  local rc=0
  local future_mode="${APP_FUTURE_MODE:-multisession}"
  local future_workers="${APP_FUTURE_WORKERS:-2}"

  if [[ "$mode" == "ON" ]]; then
    APP_HOMO_PLOT_CACHE=1 APP_ORTHO_PLOT_CACHE=1 APP_HOMO_INITIAL_VISIBLE=64 APP_ORTHO_INITIAL_VISIBLE=64 APP_ORTHO_RENDER_CHUNK_SIZE=64 APP_ORTHO_AUTO_RENDER_MORE=0 APP_ORTHO_AUTO_RENDER_DELAY_MS=0 APP_ORTHO_SERVER_RENDER_NUDGE=0 APP_HOMO_DEFER_SEQUENCE=0 APP_ORTHO_DEFER_SEQUENCE=0 APP_FOOTER_DEFER_SEQUENCE=0 APP_DEFER_FEATURE_GC=0 APP_ORTHO_ALIGNED_FAST=1 APP_FUTURE_MODE="$future_mode" APP_FUTURE_WORKERS="$future_workers" APP_PERF_TIMING=1 APP_DEBUG_LOGS=1 \
      Rscript -e "shiny::runApp('.', launch.browser=TRUE)" 2>&1 | tee "$logfile"
    rc=${PIPESTATUS[0]}
  else
    APP_HOMO_PLOT_CACHE=0 APP_ORTHO_PLOT_CACHE=0 APP_HOMO_INITIAL_VISIBLE=64 APP_ORTHO_INITIAL_VISIBLE=64 APP_ORTHO_RENDER_CHUNK_SIZE=64 APP_ORTHO_AUTO_RENDER_MORE=0 APP_ORTHO_AUTO_RENDER_DELAY_MS=0 APP_ORTHO_SERVER_RENDER_NUDGE=0 APP_HOMO_DEFER_SEQUENCE=0 APP_ORTHO_DEFER_SEQUENCE=0 APP_FOOTER_DEFER_SEQUENCE=0 APP_DEFER_FEATURE_GC=0 APP_ORTHO_ALIGNED_FAST=1 APP_FUTURE_MODE="$future_mode" APP_FUTURE_WORKERS="$future_workers" APP_PERF_TIMING=1 APP_DEBUG_LOGS=1 \
      Rscript -e "shiny::runApp('.', launch.browser=TRUE)" 2>&1 | tee "$logfile"
    rc=${PIPESTATUS[0]}
  fi

  if [[ "$rc" -eq 130 ]]; then
    echo "Captured trial $trial ($mode) via Ctrl+C."
    return 0
  fi
  if [[ "$rc" -eq 1 ]]; then
    if command -v rg >/dev/null 2>&1; then
      rg -q "\\[PERF\\]\\[(HOMO|ORTHO|HOMO_MOD|ORTHO_MOD|HOMO_TIMING|ORTHO_TIMING)\\]" "$logfile"
    else
      grep -Eq "\\[PERF\\]\\[(HOMO|ORTHO|HOMO_MOD|ORTHO_MOD|HOMO_TIMING|ORTHO_TIMING)\\]" "$logfile"
    fi
    if [[ "$?" -eq 0 ]]; then
      echo "Captured trial $trial ($mode) with exit code 1 but PERF logs present; continuing."
      return 0
    fi
  fi
  if [[ "$rc" -ne 0 ]]; then
    echo "Run failed for trial $trial ($mode), exit code: $rc"
    return "$rc"
  fi
  return 0
}

for i in $(seq 1 "$TRIALS"); do
  echo "=== Trial $i / $TRIALS: CACHE ON ==="
  run_one "ON" "$i" "$BENCH_DIR/on_${i}.log" || exit $?
  echo
  echo "=== Trial $i / $TRIALS: CACHE OFF ==="
  run_one "OFF" "$i" "$BENCH_DIR/off_${i}.log" || exit $?
  echo
done

echo "=== Aggregate benchmark summary (medians) ==="
Rscript "$ROOT_DIR/scripts/summarize_perf_benchmark_dir.R" "$BENCH_DIR"

echo
echo "Done. Logs saved in: $BENCH_DIR"
