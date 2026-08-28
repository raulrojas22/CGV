#!/usr/bin/env bash
set -euo pipefail

TARGET="${TARGET:-colors}"
URL="${URL:-https://cgev.mobilomics.org}"
N="${N:-5}"
INTERVAL="${INTERVAL:-5}"
DURATION="${DURATION:-300}"
PROFILE_ROOT="${PROFILE_ROOT:-${TMPDIR:-/tmp}/cgv-colors-capacity-profiles}"
OUT="${OUT:-colors_capacity_$(date +%Y%m%d_%H%M%S).csv}"

usage() {
  cat <<'EOF'
Usage:
  scripts/colors_capacity_test.sh open [N]
  scripts/colors_capacity_test.sh monitor [DURATION_SEC] [INTERVAL_SEC] [OUT.csv]
  scripts/colors_capacity_test.sh cleanup

Examples:
  scripts/colors_capacity_test.sh open 5
  scripts/colors_capacity_test.sh monitor 300 5 colors_capacity.csv
  scripts/colors_capacity_test.sh cleanup

Env overrides:
  TARGET=colors
  URL=https://cgev.mobilomics.org
  BROWSER_APP="Google Chrome"
EOF
}

find_browser_app() {
  if [[ -n "${BROWSER_APP:-}" ]]; then
    printf '%s\n' "$BROWSER_APP"
    return 0
  fi
  local candidates=(
    "Google Chrome"
    "Google Chrome Canary"
    "Microsoft Edge"
    "Brave Browser"
    "Chromium"
  )
  local app
  for app in "${candidates[@]}"; do
    if [[ -d "/Applications/${app}.app" || -d "${HOME}/Applications/${app}.app" ]]; then
      printf '%s\n' "$app"
      return 0
    fi
  done
  return 1
}

open_sessions() {
  local count="${1:-$N}"
  local browser
  browser="$(find_browser_app)" || {
    echo "ERROR: no encontre Chrome/Edge/Brave/Chromium. Define BROWSER_APP='Nombre App'." >&2
    exit 1
  }
  mkdir -p "$PROFILE_ROOT"
  echo "Opening ${count} isolated browser profiles with ${browser}"
  echo "Profile root: ${PROFILE_ROOT}"
  local i profile session_url
  for i in $(seq 1 "$count"); do
    profile="${PROFILE_ROOT}/profile-${i}"
    mkdir -p "$profile"
    session_url="${URL}?capacity_session=${i}&ts=$(date +%s)"
    open -na "$browser" --args \
      --user-data-dir="$profile" \
      --no-first-run \
      --new-window "$session_url"
    sleep 1
  done
  echo ""
  echo "Wait until each window loads CGV, then run the same workflow in each one."
  echo "Start metrics with:"
  echo "  scripts/colors_capacity_test.sh monitor ${DURATION} ${INTERVAL} ${OUT}"
}

remote_sample() {
  ssh "$TARGET" 'bash -s' <<'REMOTE'
set -euo pipefail
ts="$(date -u +%FT%TZ)"
sessions="$(podman ps --format '{{.Names}}' 2>/dev/null | grep -c '^sp-container' || true)"
mem_available_mib="$(free -m 2>/dev/null | awk '/^Mem:/ {print $7; found=1} END {if (!found) print ""}')"
swap_used_mib="$(free -m 2>/dev/null | awk '/^Swap:/ {print $3; found=1} END {if (!found) print ""}')"
load1="$(awk '{print $1}' /proc/loadavg 2>/dev/null || true)"
podman stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.PIDs}}' 2>/dev/null | awk -F'|' \
  -v ts="$ts" \
  -v sessions="$sessions" \
  -v mem_available_mib="$mem_available_mib" \
  -v swap_used_mib="$swap_used_mib" \
  -v load1="$load1" '
function trim(x) { gsub(/^[ \t]+|[ \t]+$/, "", x); return x }
function mem_to_mib(raw,   v,u) {
  raw = trim(raw)
  v = raw
  u = raw
  gsub(/[^0-9.]/, "", v)
  gsub(/[0-9.[:space:]]/, "", u)
  if (v == "") return ""
  if (u ~ /GiB|GB|G/) return sprintf("%.2f", v * 1024)
  if (u ~ /MiB|MB|M/) return sprintf("%.2f", v)
  if (u ~ /KiB|KB|K/) return sprintf("%.2f", v / 1024)
  if (u ~ /B/) return sprintf("%.2f", v / 1024 / 1024)
  return sprintf("%.2f", v)
}
{
  name = $1
  cpu = $2
  mem = $3
  pids = $4
  gsub(/%/, "", cpu)
  split(mem, parts, "/")
  used_raw = trim(parts[1])
  used_mib = mem_to_mib(used_raw)
  print ts "," sessions "," mem_available_mib "," swap_used_mib "," load1 "," name "," cpu "," used_mib "," pids
}'
REMOTE
}

monitor() {
  local duration="${1:-$DURATION}"
  local interval="${2:-$INTERVAL}"
  local out="${3:-$OUT}"
  local end=$((SECONDS + duration))
  echo "timestamp_utc,session_count,mem_available_mib,swap_used_mib,load1,container,cpu_percent,mem_used_mib,pids" > "$out"
  echo "Writing metrics to ${out}"
  while (( SECONDS < end )); do
    remote_sample | tee -a "$out"
    sleep "$interval"
  done
  echo ""
  echo "Done. Quick summary:"
  awk -F, '
    NR > 1 && $6 ~ /^sp-container/ {
      samples++
      cpu += $7
      if ($7 > max_cpu) max_cpu = $7
      mem += $8
      if ($8 > max_mem) max_mem = $8
      sessions[$1] = $2
      if ($2 > max_sessions) max_sessions = $2
    }
    END {
      if (samples == 0) {
        print "No CGV app containers sampled."
        exit
      }
      printf("Max sessions: %d\n", max_sessions)
      printf("Avg CGV container CPU: %.2f%%\n", cpu / samples)
      printf("Max CGV container CPU: %.2f%%\n", max_cpu)
      printf("Avg CGV container RAM: %.2f MiB\n", mem / samples)
      printf("Max CGV container RAM: %.2f MiB\n", max_mem)
    }
  ' "$out"
}

cleanup() {
  echo "Removing isolated browser profiles under ${PROFILE_ROOT}"
  rm -rf "$PROFILE_ROOT"
}

cmd="${1:-help}"
shift || true
case "$cmd" in
  open) open_sessions "$@" ;;
  monitor) monitor "$@" ;;
  cleanup) cleanup ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
