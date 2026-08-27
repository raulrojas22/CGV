#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="/Users/rarojas/Documents/A_FULLAPP"
TRIALS="${1:-3}"
BENCH_DIR="/tmp/fullapp_aligned_benchmark_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BENCH_DIR"
cd "$ROOT_DIR"

if ! [[ "$TRIALS" =~ ^[0-9]+$ ]] || [[ "$TRIALS" -lt 1 ]]; then
  echo "Invalid number of trials: $TRIALS"
  echo "Usage: $0 [num_trials]"
  exit 1
fi

echo "Aligned benchmark dir: $BENCH_DIR"
echo "This will run $TRIALS trial(s): FAST ON then FAST OFF."
echo "Fixed envs:" 
echo "  APP_HOMO_PLOT_CACHE=1 APP_ORTHO_PLOT_CACHE=1"
echo "  APP_HOMO_INITIAL_VISIBLE=64 APP_ORTHO_INITIAL_VISIBLE=64 APP_ORTHO_RENDER_CHUNK_SIZE=64"
echo "  APP_ORTHO_AUTO_RENDER_MORE=0 APP_ORTHO_SERVER_RENDER_NUDGE=0 DEFER_SEQUENCE/GC=0"
echo "  APP_ORTHO_ALIGNED_FAST=${APP_ORTHO_ALIGNED_FAST:-1}"
echo "For each run: do the same Orthologous flow and switch to Comparative Aligned, then Ctrl+C."
echo

has_perf_lines() {
  local logfile="$1"
  if command -v rg >/dev/null 2>&1; then
    rg -q "\\[PERF\\]\\[(ORTHO_ALIGNED|ORTHO_TIMING|ORTHO_UI)\\]" "$logfile"
  else
    grep -Eq "\\[PERF\\]\\[(ORTHO_ALIGNED|ORTHO_TIMING|ORTHO_UI)\\]" "$logfile"
  fi
}

run_one() {
  local mode="$1"
  local trial="$2"
  local logfile="$3"
  local fast="1"
  local rc=0

  if [[ "$mode" == "OFF" ]]; then
    fast="0"
  fi

  APP_HOMO_PLOT_CACHE=1 APP_ORTHO_PLOT_CACHE=1 \
  APP_HOMO_INITIAL_VISIBLE=64 APP_ORTHO_INITIAL_VISIBLE=64 \
  APP_ORTHO_RENDER_CHUNK_SIZE=64 APP_ORTHO_AUTO_RENDER_MORE=0 \
  APP_ORTHO_AUTO_RENDER_DELAY_MS=0 APP_ORTHO_SERVER_RENDER_NUDGE=0 \
  APP_HOMO_DEFER_SEQUENCE=0 APP_ORTHO_DEFER_SEQUENCE=0 \
  APP_FOOTER_DEFER_SEQUENCE=0 APP_DEFER_FEATURE_GC=0 \
  APP_ORTHO_ALIGNED_FAST="$fast" \
  APP_PERF_TIMING=1 APP_DEBUG_LOGS=1 \
    Rscript -e "shiny::runApp('.', launch.browser=TRUE)" 2>&1 | tee "$logfile"
  rc=${PIPESTATUS[0]}

  if [[ "$rc" -eq 130 || "$rc" -eq 2 ]]; then
    echo "Captured trial $trial ($mode) via Ctrl+C."
    return 0
  fi

  if [[ "$rc" -eq 1 || "$rc" -eq 2 ]]; then
    if has_perf_lines "$logfile"; then
      echo "Captured trial $trial ($mode) with exit code $rc but PERF logs present; continuing."
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
  echo "=== Trial $i / $TRIALS: ALIGNED FAST ON ==="
  run_one "ON" "$i" "$BENCH_DIR/on_${i}.log" || exit $?
  echo
  echo "=== Trial $i / $TRIALS: ALIGNED FAST OFF ==="
  run_one "OFF" "$i" "$BENCH_DIR/off_${i}.log" || exit $?
  echo
done

echo "=== Aggregate aligned benchmark summary (medians) ==="
Rscript "$ROOT_DIR/scripts/summarize_aligned_benchmark_dir.R" "$BENCH_DIR"

echo
echo "Done. Logs saved in: $BENCH_DIR"
